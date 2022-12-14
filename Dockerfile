# escape=`
ARG BASE_IMG_TAG=latest
FROM 598971202176.dkr.ecr.us-west-2.amazonaws.com/pd/microsoft-vc-tools-vs2019:${BASE_IMG_TAG}

ENV BUILD_DIR=C:\\pd\\build
ENV INSTALL_DIR=C:\\pd\\install
ENV PD_ROOT=C:\pd
ENV PD_UE_BUILD=/app/UE_BUILD/
ENV PYTHONPATH=c:/pd/python/pd_tools;C:/pd/tools

# run cmake to create CMakefiles. Note: the following command did not run correctly
CMD echo "cleaning up existing build/install folders"; `
    Remove-Item -LiteralPath "$env:BUILD_DIR" -Force -Recurse -ErrorAction SilentlyContinue; `
    Remove-Item -LiteralPath "$env:INSTALL_DIR" -Force -Recurse -ErrorAction SilentlyContinue; `
    mkdir "$env:BUILD_DIR"; `
    cd "$env:BUILD_DIR"; `
    cmake -G "Visual Studio 16 2019" -A x64 ..; `
    C:\\BuildTools\\MSBuild\\Current\\Bin\\MSBuild.exe pd.sln -target:ALL_BUILD:Rebuild -property:Configuration=Release; `
    C:\\BuildTools\\MSBuild\\Current\\Bin\\MSBuild.exe .\\INSTALL.vcxproj -target:build -property:Configuration=Release;


# need to clone the repo 
RUN dir

# need to run the .bat files
RUN cd C:\\pd\\build && mkdir PD_UE_BUILD\\UnrealEngine && cd PD_UE_BUILD

RUN git clone https://github.com/parallel-domain/UnrealEngine
# set up unreal engine
RUN cd UnrealEngine && Setup.bat && GenerateProjectFiles.bat 
# build ue engine
RUN cd /app/pd/tools/scripts && python pd_build_engine.py 
