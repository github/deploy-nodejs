#!/bin/bash

################################################################################
################################################################################
############# EntryPoint for Docker NodeJS Deploy Serverless ###################
################################################################################
################################################################################

#########
# NOTE: #
#########
# - https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-deploying.html
# - https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-where
# - https://developer.github.com/v3/checks/runs/

#####################
# Set exit on ERROR #
#####################
set -e

###########
# Globals #
###########
AWS_ACCESS_KEY_ID=''                        # aws_access_key_id to auth
AWS_SECRET_ACCESS_KEY=''                    # aws_secret_access_key to auth
AWS_REGION=''                               # AWS region to deploy
AWS_OUTPUT=''                               # AWS output format
S3_BUCKET=''                                # AWS S3 bucket to package and deploy
CHECK_NAME='GitHub AWS Deploy Serverless'   # Name of the GitHub Action
CHECK_ID=''                                 # GitHub Check ID that is created
AWS_CAPABILITIES_IAM=''                     # AWS IAM role for the deployed SAM
AWS_STACK_NAME=''                           # AWS Cloud Formation Stack name of SAM
SAM_CMD='/root/.linuxbrew/Homebrew/bin/sam' # Path to AWS SAM Exec
RUNTIME=''                                  # Runtime for AWS SAM App

###################
# GitHub ENV Vars #
###################
GITHUB_SHA="${GITHUB_SHA}"                # GitHub sha from the commit
GITHUB_EVENT_PATH="${GITHUB_EVENT_PATH}"  # Github Event Path
GITHUB_TOKEN="${GITHUB_TOKEN}"            # GitHub token
GITHUB_WORKSPACE="${GITHUB_WORKSPACE}"    # Github Workspace
GITHUB_URL='https://api.github.com/'      # GitHub API URL

##############
# Built Vars #
##############
GITHUB_ORG=''           # Name of the GitHub Org
GITHUB_REPO=''          # Name of the GitHub repo
USER_CONFIG_FILE="$GITHUB_WORKSPACE/.github/aws-config.yml"           # File with users configurations
START_DATE=$(date --utc "+%FT%T.%N" | sed -r 's/[[:digit:]]{7}$/Z/')  # YYYY-MM-DDTHH:MM:SSZ
FINISHED_DATE=''        # YYYY-MM-DDTHH:MM:SSZ when complete
ACTION_CONCLUSTION=''   # success, failure, neutral, cancelled, timed_out, or action_required.
ACTION_OUTPUT=''        # String to pass back to the user on the output
ERROR_FOUND=0           # Set to 1 if any errors occur in the build before the package and deploy
ERROR_CAUSE=''          # String to pass of error that was detected

################
# Default Vars #
################
DEFAULT_OUTPUT='json'                     # Default Output format
DEFAULT_REGION='us-west-2'                # Default region to deploy
LOCAL_CONFIG_FILE='/root/.aws/config'     # AWS Config file
LOCAL_CRED_FILE='/root/.aws/credentials'  # AWS Credential file

######################################################
# Variables we need to set in the ~/.aws/credentials #
# aws_access_key_id                                  #
# aws_secret_access_key                              #
######################################################

#################################################
# Variables we need to set in the ~/.aws/config #
# region                                        #
# output                                        #
#################################################

################################################################################
######################### SUB ROUTINES BELOW ###################################
################################################################################
################################################################################
#### Function ValidateConfigurationFile ########################################
ValidateConfigurationFile()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Validating input file..."

  ####################################################################
  # Validate the config file is in the repository and pull variables #
  ####################################################################
  if [ ! -f "$USER_CONFIG_FILE" ]; then
    # User file not found
    echo "ERROR! Failed to find configuration file in user repository!"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find configuration file in user repository!'
  fi

  ########################################
  # Map the variables to local variables #
  ########################################

  ###############################
  ###############################
  ## Get the aws_access_key_id ##
  ###############################
  ###############################
  AWS_ACCESS_KEY_ID=$(yq r "$USER_CONFIG_FILE" aws_access_key_id 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_ACCESS_KEY_ID" == "null" ]; then
    echo "ERROR! Failed to get [aws_access_key_id]!"
    echo "ERROR:[$AWS_ACCESS_KEY_ID]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE="Failed to get [aws_access_key_id]"
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  AWS_ACCESS_KEY_ID_NO_WHITESPACE="$(echo "${AWS_ACCESS_KEY_ID}" | tr -d '[:space:]')"
  AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_NO_WHITESPACE

  ###################################
  ###################################
  ## Get the AWS_SECRET_ACCESS_KEY ##
  ###################################
  ###################################
  AWS_SECRET_ACCESS_KEY=$(yq r "$USER_CONFIG_FILE" aws_secret_access_key 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_SECRET_ACCESS_KEY" == "null" ]; then
    echo "ERROR! Failed to get [aws_secret_access_key]!"
    echo "ERROR:[$AWS_SECRET_ACCESS_KEY]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [aws_secret_access_key]!'
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  AWS_SECRET_ACCESS_KEY_NO_WHITESPACE="$(echo "${AWS_SECRET_ACCESS_KEY}" | tr -d '[:space:]')"
  AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_NO_WHITESPACE

  #######################
  #######################
  ## Get the s3_bucket ##
  #######################
  #######################
  S3_BUCKET=$(yq r "$USER_CONFIG_FILE" s3_bucket 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$S3_BUCKET" == "null" ]; then
    echo "ERROR! Failed to get [s3_bucket]!"
    echo "ERROR:[$S3_BUCKET]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [s3_bucket]!'
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  S3_BUCKET_NO_WHITESPACE="$(echo "${S3_BUCKET}" | tr -d '[:space:]')"
  S3_BUCKET=$S3_BUCKET_NO_WHITESPACE

  ############################
  ############################
  ## Get the AWS Stack Name ##
  ############################
  ############################
  AWS_STACK_NAME=$(yq r "$USER_CONFIG_FILE" aws_stack_name 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_STACK_NAME" == "null" ]; then
    echo "ERROR! Failed to get [aws_stack_name]!"
    echo "ERROR:[$AWS_STACK_NAME]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [aws_stack_name]!'
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  AWS_STACK_NAME_NO_WHITESPACE="$(echo "${AWS_STACK_NAME}" | tr -d '[:space:]')"
  AWS_STACK_NAME=$AWS_STACK_NAME_NO_WHITESPACE

  ##########################
  ##########################
  ## Get the AWS IAM role ##
  ##########################
  ##########################
  AWS_CAPABILITIES_IAM=$(yq r "$USER_CONFIG_FILE" aws_capability_iam 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_CAPABILITIES_IAM" == "null" ]; then
    echo "ERROR! Failed to get [aws_capability_iam]!"
    echo "ERROR:[$AWS_CAPABILITIES_IAM]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [aws_capability_iam]!'
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  AWS_CAPABILITIES_IAM_NO_WHITESPACE="$(echo "${AWS_CAPABILITIES_IAM}" | tr -d '[:space:]')"
  AWS_CAPABILITIES_IAM=$AWS_CAPABILITIES_IAM_NO_WHITESPACE

  ####################
  ####################
  ## Get the region ##
  ####################
  ####################
  AWS_REGION=$(yq r "$USER_CONFIG_FILE" region 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_REGION" == "null" ]; then
    # Error
    echo "ERROR! Failed to get [region]!"
    echo "ERROR:[$AWS_REGION]"
  else
    # Fall back to default
    echo "No value provided... Defaulting to:[$DEFAULT_REGION]"
    AWS_REGION="$DEFAULT_REGION"
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  AWS_REGION_NO_WHITESPACE="$(echo "${AWS_REGION}" | tr -d '[:space:]')"
  AWS_REGION=$AWS_REGION_NO_WHITESPACE

  ####################
  ####################
  ## Get the output ##
  ####################
  ####################
  AWS_OUTPUT=$(yq r "$USER_CONFIG_FILE" output 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_OUTPUT" == "null" ]; then
    # Error
    echo "ERROR! Failed to get [output]!"
    echo "ERROR:[$AWS_OUTPUT]"
  else
    # Fall back to default
    echo "No value provided... Defaulting to:[$DEFAULT_OUTPUT]"
    AWS_OUTPUT="$DEFAULT_OUTPUT"
  fi

  ############################################
  # Clean any whitespace that may be entered #
  ############################################
  AWS_OUTPUT_NO_WHITESPACE="$(echo "${AWS_OUTPUT}" | tr -d '[:space:]')"
  AWS_OUTPUT=$AWS_OUTPUT_NO_WHITESPACE
}
################################################################################
#### Function CreateLocalConfiguration #########################################
CreateLocalConfiguration()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Creating local configuration file..."

  ########################################
  # Create the directory if not existant #
  ########################################
  MK_DIR_CMD=$(mkdir ~/.aws 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to create root directory!"
    echo "ERROR:[$MK_DIR_CMD]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to create root directory!'
  fi

  ############################################
  # Create the local file ~/.aws/credentials #
  ############################################
  CREATE_CREDS_CMD=$(echo -e "[default]\naws_access_key_id=$AWS_ACCESS_KEY_ID\naws_secret_access_key=$AWS_SECRET_ACCESS_KEY" >> $LOCAL_CRED_FILE 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to create file:[$LOCAL_CRED_FILE]!"
    echo "ERROR:[$CREATE_CREDS_CMD]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE="Failed to create file:[$LOCAL_CRED_FILE]!"
  fi

  #######################################
  # Create the local file ~/.aws/config #
  #######################################
  CREATE_CONFIG_CMD=$(echo -e "[default]\naws_access_key_id=$AWS_ACCESS_KEY_ID\naws_secret_access_key=$AWS_SECRET_ACCESS_KEY" >> $LOCAL_CONFIG_FILE 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to create file:[$LOCAL_CONFIG_FILE]!"
    echo "ERROR:[$CREATE_CONFIG_CMD]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE="Failed to create file:[$LOCAL_CONFIG_FILE]!"
  fi
}
################################################################################
#### Function GetGitHubVars ####################################################
GetGitHubVars()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Gathering GitHub information..."

  ############################
  # Validate we have a value #
  ############################
  if [ -z "$GITHUB_SHA" ]; then
    echo "ERROR! Failed to get [GITHUB_SHA]!"
    echo "ERROR:[$GITHUB_SHA]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_SHA]!'
  fi

  ############################
  # Validate we have a value #
  ############################
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR! Failed to get [GITHUB_TOKEN]!"
    echo "ERROR:[$GITHUB_TOKEN]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_TOKEN]!'
  fi

  ############################
  # Validate we have a value #
  ############################
  if [ -z "$GITHUB_WORKSPACE" ]; then
    echo "ERROR! Failed to get [GITHUB_WORKSPACE]!"
    echo "ERROR:[$GITHUB_WORKSPACE]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_WORKSPACE]!'
  fi

  ############################
  # Validate we have a value #
  ############################
  if [ -z "$GITHUB_EVENT_PATH" ]; then
    echo "ERROR! Failed to get [GITHUB_EVENT_PATH]!"
    echo "ERROR:[$GITHUB_EVENT_PATH]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_EVENT_PATH]!'
  fi

  ##################################################
  # Need to pull the GitHub Vars from the env file #
  ##################################################

  ######################
  # Get the GitHub Org #
  ######################
  # shellcheck disable=SC2002
  GITHUB_ORG=$(cat "$GITHUB_EVENT_PATH" | jq -r '.repository.owner.login' 2>&1)

  ############################
  # Validate we have a value #
  ############################
  if [ -z "$GITHUB_ORG" ]; then
    echo "ERROR! Failed to get [GITHUB_ORG]!"
    echo "ERROR:[$GITHUB_ORG]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_ORG]!'
  fi

  #######################
  # Get the GitHub Repo #
  #######################
  # shellcheck disable=SC2002
  GITHUB_REPO=$(cat "$GITHUB_EVENT_PATH"| jq -r '.repository.name' 2>&1)

  ############################
  # Validate we have a value #
  ############################
  if [ -z "$GITHUB_REPO" ]; then
    echo "ERROR! Failed to get [GITHUB_REPO]!"
    echo "ERROR:[$GITHUB_REPO]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_REPO]!'
  fi
}
################################################################################
#### Function ValidateAWSCLI ###################################################
ValidateAWSCLI()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Validating AWS information..."

  ############################################
  ############################################
  ## Validate we have access to the aws cli ##
  ############################################
  ############################################
  VALIDATE_AWS_CMD=$(which aws 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Error failed to find binary
    echo "ERROR! Failed to find aws cli!"
    echo "ERROR:[$VALIDATE_AWS_CMD]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find aws cli!'
  fi

  ############################################
  ############################################
  ## Validate we have access to the aws cli ##
  ############################################
  ############################################
  VALIDATE_SAM_CMD=$(which "$SAM_CMD" 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Error failed to find binary
    echo "ERROR! Failed to find aws sam cli!"
    echo "ERROR:[$VALIDATE_SAM_CMD]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find aws sam cli!'
  fi

  #######################################
  #######################################
  ## Validate we can see AWS s3 bucket ##
  #######################################
  #######################################
  CHECK_BUCKET_CMD=$(aws s3 ls "$S3_BUCKET" 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to access AWS S3 bucket:[$S3_BUCKET]"
    echo "ERROR:[$CHECK_BUCKET_CMD]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE="Failed to access AWS S3 bucket:[$S3_BUCKET]"
  fi
}
################################################################################
#### Function CreateCheck ######################################################
CreateCheck()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Creating GitHub Check..."

  ##########################################
  # Call to Github to create the Check API #
  ##########################################
  CREATE_CHECK_CMD=$( curl -sk -X POST \
    --url "$GITHUB_URL/repos/$GITHUB_ORG/$GITHUB_REPO/check-runs" \
    -H 'accept: application/vnd.github.antiope-preview+json' \
    -H "authorization: Bearer $GITHUB_TOKEN" \
    -H 'content-type: application/json' \
    --data "{ \"name\": \"$CHECK_NAME\", \"head_sha\": \"$GITHUB_SHA\", \"status\": \"in_progress\", \"started_at\": \"$START_DATE\" }" \
    2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to create GitHub Check!"
    echo "ERROR:[$CREATE_CHECK_CMD]"
    exit 1
  else
    #############################################
    # Need to get the check ID that was created #
    #############################################
    CHECK_ID=$(echo "$CREATE_CHECK_CMD"| jq -r '.id' 2>&1)

    ############################
    # Validate we have a value #
    ############################
    if [ -z "$CHECK_ID" ]; then
      echo "ERROR! Failed to get [CHECK_ID]!"
      echo "ERROR:[$CHECK_ID]"
      exit 1
    fi
  fi
}
################################################################################
#### Function RunDeploy ########################################################
RunDeploy()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Running AWS Deploy Process..."

  # Need to complete the following actions to deploy to AWS Serverless:
  # https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-deploying.html
  # - Package SAM template
  # - Deploy packaged SAM template

  #################
  # Build the App #
  #################
  BuidApp

  ########################
  # Package the template #
  ########################
  PackageTemplate

  #######################
  # Deploy the template #
  #######################
  DeployTemplate
}
################################################################################
#### Function BuidApp ##########################################################
BuidApp()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Building the SAM application..."

  #########################
  # Build the application #
  #########################
  BUILD_CMD=$(cd "$GITHUB_WORKSPACE" ; "$SAM_CMD" build 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Errors found
    echo "ERROR! Failed to build SAM application!"
    echo "ERROR:[$BUILD_CMD]"
    #########################################
    # Need to update the ACTION_CONCLUSTION #
    #########################################
    ERROR_FOUND=1
    ERROR_CAUSE="Failed to build SAM application:[$BUILD_CMD]!"
  fi
}
################################################################################
#### Function PackageTemplate ##################################################
PackageTemplate()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Packaging the template..."

  ##############################################
  # Check the source code for the SAM template #
  ##############################################
  if [ ! -f "$GITHUB_WORKSPACE/sam.yaml" ]; then
    echo "ERROR! Failed to find:[sam.yml] in root of repository!"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find:[sam.yml] in root of repository!'
  fi

  ############################
  # Package the SAM template #
  ############################
  SAM_PACKAGE_CMD=$("$SAM_CMD" package --template-file "$GITHUB_WORKSPACE/sam.yaml" --s3-bucket "$S3_BUCKET" --output-template-file "packaged.yaml" --region $AWS_REGION 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Errors found
    echo "ERROR! Failed to package SAM template!"
    echo "ERROR:[$SAM_PACKAGE_CMD]"
    #########################################
    # Need to update the ACTION_CONCLUSTION #
    #########################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to package SAM template!'
  fi
}
################################################################################
#### Function DeployTemplate ###################################################
DeployTemplate()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Deploying the template..."

  ############################################
  # Need to validate the package was created #
  ############################################
  if [ ! -f "$GITHUB_WORKSPACE/packaged.yml" ]; then
    echo "ERROR! Failed to find created package:[packaged.yml]"
    ###################################################
    # Set the ERROR_FOUND flag to 1 to drop out build #
    ###################################################
    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find created package:[packaged.yml]'
  fi

  ###########################
  # Deploy the SAM template #
  ###########################
  SAM_DEPLOY_CMD=$("$SAM_CMD" deploy --template-file "$GITHUB_WORKSPACE/packaged.yaml" --stack-name "$AWS_STACK_NAME" --capabilities "$AWS_CAPABILITIES_IAM" --region $AWS_REGION 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Errors found
    echo "ERROR! Failed to deploy SAM template!"
    echo "ERROR:[$SAM_DEPLOY_CMD]"
    #########################################
    # Need to update the ACTION_CONCLUSTION #
    #########################################
    ACTION_CONCLUSTION='failure'
    ACTION_OUTPUT="Failed to deploy SAM App"
  else
    # Success
    #########################################
    # Need to update the ACTION_CONCLUSTION #
    #########################################
    ACTION_CONCLUSTION='success'
    ACTION_OUTPUT="Successfully Deployed SAM App"
  fi
}
################################################################################
#### Function ValidateSourceAndRuntime #########################################
ValidateSourceAndRuntime()
{
  ##############################################
  # Validate the user has the template.yml and #
  # we have the correct runtime set            #
  ##############################################

  ############################################
  # Look for the template in the source code #
  ############################################
  if [ ! -f "$GITHUB_WORKSPACE/template.yml" ]; then
    # Errors found
    echo "ERROR! Failed to find template:[$GITHUB_WORKSPACE/template.yml]!"
    #########################################
    # Need to update the ACTION_CONCLUSTION #
    #########################################
    ERROR_FOUND=1
    ERROR_CAUSE="Failed to find template:[$GITHUB_WORKSPACE/template.yml]!"
  else
    #################################
    # Get the runtime from template #
    #################################
    GET_RUNTIME_CMD=$(grep "Runtime" "$GITHUB_WORKSPACE/template.yml" 2>&1)

    #######################
    # Load the error code #
    #######################
    ERROR_CODE=$?

    #############################################
    # Clean any whitespace that may be returned #
    #############################################
    GET_RUNTIME_CMD_NO_WHITESPACE="$(echo "${GET_RUNTIME_CMD}" | tr -d '[:space:]')"
    GET_RUNTIME_CMD=$GET_RUNTIME_CMD_NO_WHITESPACE

    ##############################
    # Check the shell for errors #
    ##############################
    if [ $ERROR_CODE -ne 0 ]; then
      # Errors found
      echo "ERROR! Failed to find [Runtime] in:[$GITHUB_WORKSPACE/template.yml]!"
      #########################################
      # Need to update the ACTION_CONCLUSTION #
      #########################################
      ERROR_FOUND=1
      ERROR_CAUSE="Failed to find [Runtime] in:[$GITHUB_WORKSPACE/template.yml]!"
    else
      ###########################
      # Need to set the runtime #
      ###########################
      RUNTIME=$(echo "$GET_RUNTIME_CMD" | cut -f2 -d':')
    fi
  fi

  ##################################################
  # Need to set the Runtime for the app deployment #
  ##################################################
  SetRuntime "$RUNTIME"
}
################################################################################
#### Function SetRuntime #######################################################
SetRuntime()
{
  ################
  # Pull in vars #
  ################
  RUNTIME=$1

  ###########################################
  # Remove the 'NodeJS' and get the version #
  ###########################################
  VERSION=$(echo "${RUNTIME:6}")

  # echo "Version:[$VERSION]"

  ################
  # Set the vars #
  ################
  VERSION_MAJOR=$(echo "$VERSION" | cut -f1 -d'.')
  VERSION_MINOR=$(echo "$VERSION" | cut -f2 -d'.')

  ################################
  # Check if minor is x or undef #
  ################################
  if [ "$VERSION_MINOR" == "x" ] || [ -z "$VERSION_MINOR" ]; then
    #########################
    # Need to set to latest #
    #########################
    NVM_INSTALL_CMD=$(nvm install "$VERSION_MAJOR" ; nvm use "$VERSION_MAJOR" 2>&1)

    #######################
    # Load the error code #
    #######################
    ERROR_CODE=$?

    ##############################
    # Check the shell for errors #
    ##############################
    if [ $ERROR_CODE -ne 0 ]; then
      echo "ERROR! Failed to install and set Node:[$VERSION_MAJOR]!"
      #########################################
      # Need to update the ACTION_CONCLUSTION #
      #########################################
      ERROR_FOUND=1
      ERROR_CAUSE="Failed to install and set Node:[$VERSION_MAJOR]!"
    fi
  else
    #########################
    # Running exact version #
    #########################
    NVM_INSTALL_CMD=$(nvm install "$VERSION" ; nvm use "$VERSION" 2>&1)

    #######################
    # Load the error code #
    #######################
    ERROR_CODE=$?

    ##############################
    # Check the shell for errors #
    ##############################
    if [ $ERROR_CODE -ne 0 ]; then
      echo "ERROR! Failed to install and set Node:[$VERSION]!"
      #########################################
      # Need to update the ACTION_CONCLUSTION #
      #########################################
      ERROR_FOUND=1
      ERROR_CAUSE="Failed to install and set Node:[$VERSION]!"
    fi
  fi
}
################################################################################
#### Function UpdateCheck ######################################################
UpdateCheck()
{
  ##########
  # Prints #
  ##########
  echo "--------------------------------------------"
  echo "Updating GitHub Check..."

  ###########################
  # Build the finished time #
  ###########################
  FINISHED_DATE=$(date --utc "+%FT%T.%N" | sed -r 's/[[:digit:]]{7}$/Z/')

  ######################################################
  # Set the conclusion to failure if errors were found #
  ######################################################
  if [ $ERROR_FOUND -ne 0 ]; then
    # Set conclusion
    ACTION_CONCLUSTION='failure'
    # Set the output
    ACTION_OUTPUT="$ERROR_CAUSE"
  fi

  ##########################################
  # Call to Github to update the Check API #
  ##########################################
  UPDATE_CHECK_CMD=$( curl -sk -X PATCH \
    --url "$GITHUB_URL/repos/$GITHUB_ORG/$GITHUB_REPO/check-runs/$CHECK_ID" \
    -H 'accept: application/vnd.github.antiope-preview+json' \
    -H "authorization: Bearer $GITHUB_TOKEN" \
    -H 'content-type: application/json' \
    --data "{ \"name\": \"$CHECK_NAME\", \"head_sha\": \"$GITHUB_SHA\", \"status\": \"completed\", \"completed_at\": \"$FINISHED_DATE\" , \"conclusion\": \"$ACTION_CONCLUSTION\" , \"output\": { \"title\": \"AWS SAM Deploy Summary\" , \"text\": \"$ACTION_OUTPUT\"} }" \
    2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to update GitHub Check!"
    echo "ERROR:[$UPDATE_CHECK_CMD]"
    exit 1
  fi
}
################################################################################
################################# MAIN #########################################
################################################################################

# Go into loop if no errors detected
if [ $ERROR_FOUND -eq 0 ]; then
  #######################
  # Get Github Env Vars #
  #######################
  # Need to pull in all the Github variables
  # needed to connect back and update checks
  GetGitHubVars
fi

# Go into loop if no errors detected
if [ $ERROR_FOUND -eq 0 ]; then
  #######################################
  # Validate We have configuration file #
  #######################################
  # Look for the users configuration file to
  # connect to AWS and start the Serverless app
  ValidateConfigurationFile
fi

# Go into loop if no errors detected
if [ $ERROR_FOUND -eq 0 ]; then
  ####################
  # Validate AWS CLI #
  ####################
  # Need to validate we have the aws cli installed
  # And avilable for usage
  ValidateAWSCLI
fi

# Go into loop if no errors detected
if [ $ERROR_FOUND -eq 0 ]; then
  ###################################
  # Create local configuration file #
  ###################################
  # Create the local configuration file used
  # to connect to AWS and deploy the Serverless app
  CreateLocalConfiguration
fi

########################################
# Validate the user source and runtime #
########################################
ValidateSourceAndRuntime

################
# Create Check #
################
# Create the check in GitHub to let the
# user know we are running the deploy action
# We always want to inform user of the process
CreateCheck

# Go into loop if no errors detected
if [ $ERROR_FOUND -eq 0 ]; then
  ##############
  # Run Deploy #
  ##############
  # Run the actual deployment of the NodeJS
  # to AWS Serverless
  RunDeploy
fi

################
# Update Check #
################
# Update the check with the status
# of the deployment
# We always want to inform user of the process
UpdateCheck
