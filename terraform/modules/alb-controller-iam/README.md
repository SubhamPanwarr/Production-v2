# ALB Controller IAM module

This module contains AWS IAM resources only.

The AWS Load Balancer Controller Kubernetes ServiceAccount and controller
deployment are installed after Terraform, so Kubernetes resources are not
stored in the infrastructure or add-ons Terraform state.
