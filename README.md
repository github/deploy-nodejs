# deploy-nodejs

This repository is for the **GitHub** Action to deploy a **NodeJS** application to **AWS** Serverless.  
Developers on **GitHub** can call this Action to take their current **NodeJS** application, and pass basic variables to help deploy their application.

## How to use

To use this **GitHub** Action you will need to complete the following:
- Copy the template file `TEMPLATE/aws-config.yml` to your repository in the location: `.github/aws-config.yml`
- Validate all variables are correct and allow for proper permissions on **AWS**
- Add the **Github** Action: **Deploy NodeJS to AWS Serverless** to your current **Github** Actions workflow
- Enjoy your application on **AWS**

### Example GitHub Action Workflow

In your repository you should have a `workflows` folder similar to below:

- `.github/workflows/deploy.yml`

This file should have the following code:

```yml
---
###########################
###########################
## Deploy GitHub Actions ##
###########################
###########################
name: NodeJS AWS SAM Deploy

#
# Documentation:
# https://help.github.com/en/articles/workflow-syntax-for-github-actions
#

#############################
# Start the job on all push #
#############################
on: ['push']

###############
# Set the Job #
###############
jobs:
  build:
    # Name the Job
    name: NodeJS AWS SAM Deploy
    # Set the agent to run on
    runs-on: ubuntu-latest

    ##################
    # Load all steps #
    ##################
    steps:
      ##########################
      # Checkout the code base #
      ##########################
      - name: Checkout Code
        uses: actions/checkout@master

      #############################
      # Run NodeJS AWS SAM Deploy #
      #############################
      - name: NodeJS AWS SAM Deploy
        uses: docker://admiralawkbar/aws-nodejs:latest
        env:
           AWS_ACCESS_KEY: ${{ secrets.AWS_ACCESS_KEY }}
           AWS_SECRET_KEY: ${{ secrets.AWS_SECRET_KEY }}
...
```

**NOTE:** You will need to create the GitHub `Secrets` for:
- **AWS_ACCESS_KEY**
  - Valid AWS Access key to authenticate to your AWS Account
- **AWS_SECRET_KEY**
  - Valid AWS Access Secret key to authenticate to your AWS Account

## How to contribute

If you would like to help contribute to this **Github** Action, please see [CONTRIBUTING](https://github.com/github/deploy-nodejs/blob/master/.github/CONTRIBUTING.md)

--------------------------------------------------------------------------------

### License

- [License](https://github.com/github/deploy-nodejs/blob/master/LICENSE)
