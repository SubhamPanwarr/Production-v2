locals {
  jenkins_ecr_user_arn = "arn:aws:iam::523881172609:user/jenkins-v3-ecr-publisher"
}

resource "aws_iam_role" "jenkins_cd" {
  name = "production-v3-jenkins-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = local.jenkins_ecr_user_arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "Production-v3"
    Environment = "lab"
  }
}

resource "aws_iam_role_policy" "jenkins_cd_eks" {
  name = "production-v3-jenkins-eks-describe"
  role = aws_iam_role.jenkins_cd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = data.aws_eks_cluster.this.arn
    }]
  })
}

resource "aws_iam_user_policy" "jenkins_assume_cd" {
  name = "production-v3-assume-deploy-role"
  user = "jenkins-v3-ecr-publisher"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sts:AssumeRole"]
      Resource = aws_iam_role.jenkins_cd.arn
    }]
  })
}

resource "aws_eks_access_entry" "jenkins_cd" {
  cluster_name      = data.terraform_remote_state.infra.outputs.eks_cluster_name
  principal_arn     = aws_iam_role.jenkins_cd.arn
  kubernetes_groups = ["production-v3-deployers"]
  type              = "STANDARD"
}

output "jenkins_cd_role_arn" {
  value = aws_iam_role.jenkins_cd.arn
}
