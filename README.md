# deploy-nodejs

This repository is for the **GitHub** Action to deploy a **NodeJS** application to **AWS** Serverless.  
Developers on **GitHub** can call this Action to take their current **NodeJS** application, and pass basic variables to help deploy

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
name: Deploy Action

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
    name: Deploy NodeJS
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

      ##################
      # Run Deployment #
      ##################
      - name: Run Deployment
        uses: github/deploy-nodejs@master
...
```

## How to contribute

If you would like to help contribute to this **Github** Action, please see [CONTRIBUTING](https://github.com/github/deploy-nodejs/blob/master/.github/CONTRIBUTING.md)

--------------------------------------------------------------------------------

### License

- [License](https://github.com/github/deploy-nodejs/blob/master/LICENSE)
