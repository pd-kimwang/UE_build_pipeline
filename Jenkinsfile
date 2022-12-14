def dateFormat = "yyyy-MM-dd_HH:mm:ss.SSS000"
def UEBuildImage = null

def p4Spec = '''
                //depot/3rdparty/... //${P4_CLIENT}/3rdparty/...
                //depot/assets/asset_registry.db //${P4_CLIENT}/assets/asset_registry.db
                //depot/assets/point_cache/... //${P4_CLIENT}/assets/point_cache/...
                //depot/assets/lidar/... //${P4_CLIENT}/assets/lidar/...
                //depot/customer/... //${P4_CLIENT}/customer/...
                //depot/tools/... //${P4_CLIENT}/tools/...
                //depot/shared/... //${P4_CLIENT}/shared/...
                //depot/CMakeLists.txt //${P4_CLIENT}/CMakeLists.txt
            '''

pipeline {
    agent {
        label 'windows'
    }

    parameters {

    }

    environment {

    }

    


    stages {
        // need to set environment variables (the ones missing from the docker image)
        stage('Setup Build Environment') {
            // Setup the build environment variables here
            steps {
                script {
                    // Locks the build number across stage restarts
                    env.BUILD_UID = "${JOB_BASE_NAME}-${BUILD_NUMBER}"
                    env.ARTIFACT_TYPE = "code"

                    env.codeArtifactUUID = UUID.randomUUID().toString()

                    // Print environment summary
                    def summary = createSummary("attribute.png")
                    summary.appendText("""
                        <h2>Build Info</h2>
                        <table>
                            <tr>
                                <td>Artifact UID</td>
                                <td>${env.codeArtifactUUID}</td>
                            </tr>
                        </table>
                    """)
                    addInfoBadge("UID: ${env.codeArtifactUUID}")
                }
            }

        } // stage: build environment
        stage('Checkout Code') {
            steps {
                script {
                    p4CheckoutCode = checkout perforce(
                        credential: 'p4-buildbot',
                        populate: autoClean(
                            delete: true,
                            modtime: false,
                            parallel: [enable: true, minbytes: '0', minfiles: '0', threads: '0'],
                            pin: '',
                            quiet: true,
                            replace: true,
                            tidy: false
                        ), // populate
                        workspace: manualSpec(
                            charset: 'none',
                            cleanup: false,
                            name: 'jenkins-script-${JOB_NAME}-${EXECUTOR_NUMBER}',
                            pinHost: false,
                            spec: clientSpec(
                                allwrite: false, backup: true, changeView: '', clobber: true, compress: false,
                                line: 'LOCAL', locked: false, modtime: false, rmdir: false, serverID: '',
                                streamName: '', type: 'WRITABLE',
                                view: p4Spec
                            ) // spec
                        ) // workspace
                    ) // checkout perforce
                } // script
            }
        } // stage: Checkout Code
        
        stage('Build Unreal Engine') {
            steps {
                echo 'Starting unreal engine build'
                script {
                    UEBuildStartDate = (new Date()).format(dateFormat, TimeZone.getTimeZone('UTC'))
                    UEBuildImage = docker.build(
                        "pd/UnrealEngine4:${env.BUILD_UID}",
                        (
                            "-f Dockerfile " +
                            "."
                        )
                    )

                    UEBuildEndDate = (new Date()).format(dateFormat, TimeZone.getTimeZone('UTC'))
                }
            }
        } // stage: build code

        stage ('Uploading outputs')
        {
            parallel {
                stage('Register Code Build Artifact') {
                    steps {
                        echo 'Register Code Build Artifact'
                        script {
                            // Upload artifact
                            powershell("""
                                docker run --rm ${codeBuildImage.imageName()} '
                                python build\\pd_push_artifact.py \
                                --artifact_path "C:\\pd\\install" \
                                --artifact_uid "${env.codeArtifactUUID}" \
                                --build_uid "${env.codeArtifactUUID}" \
                                --artifact_type "${env.ARTIFACT_TYPE}" \
                                --artifact_key "${env.JOB_NAME}-${env.BUILD_UID}" \
                                --start_date "${codeBuildStartDate}" \
                                --end_date "${codeBuildEndDate}" \
                                --platform Win64 \
                                --status Success \
                                --no-gcp --no-s3'
                            """)
                        }
                    }
                } // stage: Register Code Build Artifact

                stage('S3 Upload') {
                    steps {
                        echo 'Uploading UE build artifact to S3'
                        script {
                             // Upload artifact to S3 using host's aws cli outside docker
                             // This needs to change once we can map host network to docker container
                            powershell(script:"aws s3 sync ${env.WORKSPACE}\\install s3://paralleldomain-pipeline/artifacts/${codeArtifactUUID}")
                        }
                    }
                } // stage: S3 Upload
                stage('Push UE Image to ECR') {
                    steps {
                        echo 'Pushing build-environment image to ECR'
                        script {
                            ecrPwd = powershell(script:"(Get-ECRLoginCommand).Password", returnStdout: true).trim()
                            powershell(script:"docker login --username AWS --password ${ecrPwd} ${ECR_URL}")

                            docker.withRegistry("https://${ECR_URL}") {
                                    UEBuildImage.push()
                                    UEBuildImage.push("latest")
                                }

                        }
                    }
                } // stage: Push CodeBuild Runtime Image to ECR


            } // parallel
        } // stage: Uploading outputs

    }

    post {
        success {
            script {
                def attachments = [
                        [
                            "color" : "#36a64f",
                            "blocks": [
                                        [
                                            "type": "header",
                                            "text": [
                                                "type": "plain_text",
                                                "text": "[New Artifact] UnrealEngine Build - Win64"
                                            ]
                                        ],
                                        [
                                            "type": "divider"
                                        ],
                                        [
                                            "type": "section",
                                            "text": [
                                                "type": "mrkdwn",
                                                "text": "*Details*"
                                            ],
                                            "fields": [
                                                [
                                                    "type": "mrkdwn",
                                                    "text": "*Changelist*"
                                                ],
                                                [
                                                    "type": "mrkdwn",
                                                    "text": "*UnrealEngine Build Win64 UUID*"
                                                ],
                                                [
                                                    "type": "mrkdwn",
                                                    "text": "`CL $env.P4_CL_CODE`"
                                                ],
                                                [
                                                    "type": "mrkdwn",
                                                    "text": "`$codeArtifactUUID`"
                                                ],

                                            ],
                                            "accessory": [
                                                "type": "image",
                                                "image_url": "https://winaero.com/blog/wp-content/uploads/2019/06/WIndows-Terminal-icon.png",
                                                "alt_text": "UE Build win64 icon"
                                            ]
                                        ],
                                        [
                                            "type": "section",
                                            "text": [
                                                "type": "mrkdwn",
                                                "text": "<$env.BUILD_URL|View Build>"
                                            ]
                                        ]
                            ]
                    ]
                ]
                // send to a test channel, only visible to me
                slackSend(channel: "#testtest", attachments: attachments)

                // Post artifacts info
                rtp(parserName:'HTML', stableText: """
                    <h2>Artifacts</h2>
                    <table>
                        <tr>
                            <td>S3 - Code Artifact UUID</td>
                            <td>
                                <a href="https://s3.console.aws.amazon.com/s3/buckets/paralleldomain-pipeline?region=us-west-2&prefix=artifacts/${codeArtifactUUID}/&showversions=false/">
                                    ${codeArtifactUUID}
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td>GCP - Code Artifact UUID</td>
                            <td>
                                <a href="https://console.cloud.google.com/storage/browser/pd-pipeline/artifacts/${codeArtifactUUID}">
                                    ${codeArtifactUUID}
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td>ChangeList</td>
                            <td>${env.P4_CL_CODE}</td>
                        </tr>
                        <tr>
                            <td>Artifact Type</td>
                            <td>${env.ARTIFACT_TYPE}</td>
                        </tr>
                        <tr>
                            <td>ECR Image URI</td>
                            <td>${ECR_URL}/${codeBuildRuntimeImageECR}:latest, ${ECR_URL}/${codeBuildRuntimeImage.imageName()}</td>
                        </tr>
                    </table>
                """)

            } //script
        } // success

        failure {
            script {

                def attachments = [
                        [
                            "color" : "#a30200",
                            "blocks": [
                                [
                                    "type": "header",
                                    "text": [
                                        "type": "plain_text",
                                        "text": "[FAIL] UE4 Engine Build - Win64"
                                    ]
                                ],
                                [
                                    "type": "divider"
                                ],
                                [
                                    "type": "section",
                                    "text": [
                                        "type": "mrkdwn",
                                        "text": "*Details*"
                                    ],
                                    "fields": [
                                        [
                                            "type": "mrkdwn",
                                            "text": "*Changelist*"
                                        ],
                                        [
                                            "type": "mrkdwn",
                                            "text": "`CL $env.P4_CL_CODE`"
                                        ]
                                    ]
                                ],
                                [
                                    "type": "section",
                                    "text": [
                                        "type": "mrkdwn",
                                        "text": "<$env.BUILD_URL|View Build>"
                                    ]
                                ]
                            ]
                    ]
                ]

                // sending to a test channel, only visible to me
                slackSend(channel: "#testtest", attachments: attachments)

            } //script
        } // failure

    } // post


}