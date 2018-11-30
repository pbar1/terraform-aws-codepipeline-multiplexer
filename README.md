# AWS CodePipeline Multiplexer

Terraform module to dynamically create AWS CodePipeline source steps

Currently, AWS CodePipeline does not support catching arbitrary source branches. This is a desirable feature as it allows short-lived branches such as pull requests to trigger builds and tests. This module solves that by attaching a webhook to the source GitHub repository that posts back to AWS API Gateway upon pull request events. API Gateway invokes AWS Lambda, which in turn clones the default CodePipeline source step and replaces its selected branch with the PR branch. A similar process takes place upon pull request closed events to destroy the ephemeral source step.

## Diagram

<p align="center">
  <img src="./assets/diagram.png"/>
</p>

