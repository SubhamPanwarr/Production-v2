terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["523881172609"]
}

data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket       = "subham-production-terraform-state"
    key          = "production-v3/infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.infra.outputs.eks_cluster_name
}

data "aws_secretsmanager_secret" "app" {
  name = "production-v3/java-login-app/db"
}

module "app_secrets_access" {
  source = "../../../modules/eks-secrets-access"

  cluster_name = data.terraform_remote_state.infra.outputs.eks_cluster_name

  oidc_provider_arn = data.terraform_remote_state.infra.outputs.eks_oidc_provider_arn
  oidc_provider_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  namespace            = "production-v3"
  service_account_name = "java-login-app"

  secret_arn = data.aws_secretsmanager_secret.app.arn

  tags = {
    Project     = "Production-v3"
    Environment = "lab"
  }
}

resource "aws_eks_addon" "secrets_provider" {
  cluster_name = data.terraform_remote_state.infra.outputs.eks_cluster_name
  addon_name   = "aws-secrets-store-csi-driver-provider"
}

output "app_secret_reader_role_arn" {
  value = module.app_secrets_access.role_arn
}
