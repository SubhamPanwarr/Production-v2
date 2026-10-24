# Production-v2 setup order

## Build order

1. Create/push the Git repository.
2. Configure the Terraform backend and local tfvars.
3. Apply `terraform/environments/prod/infra`.
4. Configure kubeconfig and verify EKS nodes.
5. Apply `terraform/environments/prod/addons`.
6. Install AWS Load Balancer Controller.
7. Build/push the app image to ECR.
8. Apply Kubernetes YAML with `scripts/deploy-kubernetes.sh`.
9. Verify, then apply NetworkPolicy last.

## State keys

- Infrastructure: `production-v2/infra/terraform.tfstate`
- Add-ons: `production-v2/addons/terraform.tfstate`

Never commit `backend.hcl`, `terraform.tfvars`, state files, plan files, private keys, or `.env`.
The example files are safe to commit.
