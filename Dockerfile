#################################################
#################################################
## Dockerfile to run AWS Serverless NodeJS App ##
#################################################
#################################################

##################
# Get base image #
##################
FROM python:alpine

#########################################
# Label the instance and set maintainer #
#########################################
LABEL com.github.actions.name="NodeJS Deploy AWS Serverless" \
      com.github.actions.description="Deploy your NodeJS app to AWS Serverless" \
      com.github.actions.icon="code" \
      com.github.actions.color="red" \
      maintainer="GitHub DevOps <github_devops@github.com>"

##################
# Run the Update #
##################
RUN apk add --no-cache \
    bash git musl-dev jq \
    npm nodejs bash git musl-dev jq gcc curl

RUN pip install --upgrade --no-cache-dir \
    awscli aws-sam-cli yq

# Note: For now, we will use the builtin npm and nodejs
# ##############################
# # Install NVM for all NodeJS #
# ##############################
# ENV NVM_DIR /usr/local/nvm
# ENV NODE_VERSION 10.16.3
#
# RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.20.0/install.sh | bash \
#     && . $NVM_DIR/nvm.sh \
#     && mkdir $NVM_DIR/versions \
#     && nvm install $NODE_VERSION \
#     && nvm alias default $NODE_VERSION \
#     && nvm use default
#
# ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
# ENV PATH      $NVM_DIR/v$NODE_VERSION/bin:$PATH

####################################
# Setup AWS CLI Command Completion #
####################################
RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc

###########################################
# Load GitHub Env Vars for Github Actions #
###########################################
ENV GITHUB_SHA=${GITHUB_SHA}
ENV GITHUB_EVENT_PATH=${GITHUB_EVENT_PATH}
ENV GITHUB_WORKSPACE=${GITHUB_WORKSPACE}
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}

###########################
# Copy files to container #
###########################
COPY lib /action/lib

######################
# Set the entrypoint #
######################
ENTRYPOINT ["/action/lib/entrypoint.sh"]
