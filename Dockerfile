###############################################
# Dockerfile to run AWS Serverless NodeJS App #
###############################################

# Get Ubuntu 18.04 base image
FROM ubuntu:18.04

# Run the Update
RUN apt-get update && apt-get upgrade -y

# Add lib to setup additional libs
RUN apt-get install -y software-properties-common

# Run and get repository
RUN add-apt-repository ppa:rmescandon/yq

# Run the Update
RUN apt-get update

# Install pre-reqs
RUN apt-get install -y \
    && python curl yq jq
    && build-essential curl file git

# download and install pip
RUN curl -sO https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

# install AWS CLI
RUN pip install awscli

# Setup AWS CLI Command Completion
RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc

# Setup AWS SAM CLI
# Have to install a bit oddly as you cant install normally from docker
RUN git clone https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew \
    && mkdir ~/.linuxbrew/bin \
    && ln -s ~/.linuxbrew/Homebrew/bin/brew ~/.linuxbrew/bin \
    && eval $(~/.linuxbrew/bin/brew shellenv)

# Install AWS SAM CLI
RUN /root/.linuxbrew/Homebrew/bin/brew tap aws/tap \
    && /root/.linuxbrew/Homebrew/bin/brew install aws-sam-cli

# Label the instance
LABEL com.github.actions.name="NodeJS Deploy AWS Serverless"
LABEL com.github.actions.description="Deploy your NodeJS app to AWS Serverless"
LABEL com.github.actions.icon="code"
LABEL com.github.actions.color="red"

# Set the maintainer
LABEL maintainer="GitHub DevOps <github_devops@github.com>"

# Copy files to container
COPY lib /action/lib

# Set the entrypoint
#ENTRYPOINT ["/action/lib/entrypoint.sh"]

# Enable for DEBUG to keep agent alive
CMD tail -f /dev/null
