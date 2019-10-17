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
    nodejs npm gcc

RUN pip install --upgrade --no-cache-dir \
    awscli aws-sam-cli yq

####################################
# Setup AWS CLI Command Completion #
####################################
RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc

###########################################
# Load GitHub Env Vars for Github Actions #
###########################################
ENV GITHUB_SHA=${GITHUB_SHA}
ENV GITHUB_EVENT_PATH=${GITHUB_EVENT_PATH}
ENV GITHUB_TOKEN=${GITHUB_TOKEN}
ENV GITHUB_WORKSPACE=${GITHUB_WORKSPACE}

###########################
# Copy files to container #
###########################
COPY lib /action/lib

######################
# Set the entrypoint #
######################
ENTRYPOINT ["/action/lib/entrypoint.sh"]
