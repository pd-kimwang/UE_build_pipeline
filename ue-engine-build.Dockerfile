# syntax=docker/dockerfile:experimental

#
# Build stage: set up p4 environment
#  * Installs perforce
#
FROM ubuntu:20.04 as p4-env

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apt-get update && apt-get install -y \
    wget \
    gettext

RUN groupadd -g $GROUP_ID user && \
    useradd -r -m -u $USER_ID -g user user
RUN mkdir -p /app && chown user:user /app

USER user

# Perforce
COPY --chown=user:user ./tools/build/configs/p4config /app/.p4config
COPY --chown=user:user ./tools/build/p4 /app/p4
RUN chmod +x /app/p4

ENV P4CONFIG=/app/.p4config
ENV P4TRUST=/app/.p4trust
ENV P4TICKETS=/app/.p4tickets
ENV PATH="/app:${PATH}"

# P4 credentials
RUN --mount=type=secret,id=p4-pass,uid=1000 \
    p4 trust -y && \
    cat /run/secrets/p4-pass | p4 login -a

# Directory for code root (hard-coded in the p4 workspace spec)
RUN mkdir -p /app/pd

# Verify that login works
RUN p4 login -s


#
# Helper stage: download awscli package
#  * Install package by running script /aws/install
#
FROM 598971202176.dkr.ecr.us-west-2.amazonaws.com/3rdparty/alpine:3.14.0 as awscli-install
ARG awscli_version=2.1.21
RUN apk --update add curl && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$awscli_version.zip" -o awscli.zip && \
    unzip -q awscli.zip



#
# Build stage: tools-src
#  * Copies tools src files to /app/pd/tools
#
FROM ubuntu:20.04 as tools-src

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apt-get update && apt-get install -y wget

RUN groupadd -g $GROUP_ID user && \
    useradd -r -m -u $USER_ID -g user user
RUN mkdir -p /app && chown user:user /app

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    apt-transport-https \
    ca-certificates \
    gnupg \
    unzip \
    p7zip-full \
    python3.8 \
    python3-distutils \
    python3-evdev \
    uuid-runtime \
    dos2unix && \
    curl https://bootstrap.pypa.io/pip/get-pip.py | python3

RUN python3 -m pip install --upgrade pip==22.3


# Install awscli
RUN --mount=type=bind,from=awscli-install,source=/aws,target=/aws \
    /aws/install

RUN mkdir -p /app/pd /app/pd/tools && chown user:user /app/pd /app/pd/tools

# Setup python env for tools
COPY --chown=user:user tools/build/py_envs/tools_image/requirements.txt /app/requirements.txt
RUN pip3 install -r /app/requirements.txt
ENV PYTHONPATH=/app/pd/tools:/app/pd/tools/pd_tools

USER user

COPY --chown=user:user tools /app/pd/tools

WORKDIR /app/pd/tools

# need to clone the repo 
ENV PYTHONPATH=/app/pd/python/pd_tools:/app/pd/tools
ENV PD_ROOT=/app/pd
# might need to mkdir  
ENV PD_UE_BUILD=/app/UE_BUILD/UnrealEngine

# need to install visual studio and run the .bat files
RUN git clone https://github.com/parallel-domain/UnrealEngine
RUN cd /app/pd/tools/scripts \
    python pd_build_engine.py
