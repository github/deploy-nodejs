#################################################
#################################################
## Dockerfile to run AWS Serverless NodeJS App ##
#################################################
#################################################

###############################
# Get Ubuntu 18.04 base image #
###############################
FROM ubuntu:18.04

##################
# Run the Update #
##################
RUN apt-get update \
    && apt-get upgrade -y

##################################################
# Add lib and repo deps to setup additional libs #
##################################################
RUN apt-get install -y software-properties-common \
    && add-apt-repository ppa:rmescandon/yq \
    && apt-get update

####################
# Install pre-reqs #
####################
RUN apt-get install -y \
    python \
    curl \
    yq \
    jq \
    locales \
    build-essential \
    curl \
    file \
    git

##############################
# Install NVM for all NodeJS #
##############################
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 10.16.3

RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.20.0/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && mkdir $NVM_DIR/versions \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/v$NODE_VERSION/bin:$PATH

############################
# Download and install pip #
############################
RUN curl -sO https://bootstrap.pypa.io/get-pip.py \
    && python get-pip.py

###################
# Install AWS CLI #
###################
RUN pip install awscli

####################################
# Setup AWS CLI Command Completion #
####################################
RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc

#####################
# Setup AWS SAM CLI #
#####################
# - https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install-linux.html
# - https://github.com/Linuxbrew/brew
# Have to install a bit oddly as you cant install normally from docker
RUN localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && git clone https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew \
    && mkdir ~/.linuxbrew/bin \
    && ln -s ~/.linuxbrew/Homebrew/bin/brew ~/.linuxbrew/bin \
    && eval $(~/.linuxbrew/bin/brew shellenv) \
    && /root/.linuxbrew/Homebrew/bin/brew tap aws/tap \
    && /root/.linuxbrew/Homebrew/bin/brew install aws-sam-cli

ENV PATH="/root/.linuxbrew/Homebrew/bin:${PATH}"

#########################################
# Label the instance and set maintainer #
#########################################
LABEL com.github.actions.name="NodeJS Deploy AWS Serverless" \
      com.github.actions.description="Deploy your NodeJS app to AWS Serverless" \
      com.github.actions.icon="code" \
      com.github.actions.color="red" \
      maintainer="GitHub DevOps <github_devops@github.com>"

###########################
# Copy files to container #
###########################
COPY lib /action/lib

######################
# Set the entrypoint #
######################
ENTRYPOINT ["/action/lib/entrypoint.sh"]

########################################
# Enable for DEBUG to keep agent alive #
########################################
#CMD tail -f /dev/null
