# Rebuild Production-v2 v3 from zero

This runbook targets the `v3` branch of `SubhamPanwarr/Production-v2`. Terraform manages AWS infrastructure, EKS add-ons, the Prometheus/Grafana Helm release, and the production Kubernetes YAML through the Kubernetes provider. Jenkins runs in WSL and uses a pipeline stored in the same repository.

## 0. Prerequisites

From WSL install/configure AWS CLI, Terraform, kubectl, Docker, Git, and Helm. Configure AWS credentials with permission to create the Terraform infrastructure, read/write the state bucket, push to ECR, and access the EKS cluster. Confirm `aws sts get-caller-identity` returns the intended account. The overlays in this bundle are intended to be copied into a checkout of `Production-v2` branch `v3`, preserving the repository's existing modules and variable files.

The S3 Terraform state bucket is a prerequisite and should not be destroyed with the application. If it was also deleted, recreate a versioned, encrypted S3 bucket with public access blocked before initializing the infrastructure state. Use a globally unique bucket name and keep the bucket in the same AWS account/region used for the states.

## 1. Apply AWS infrastructure

```bash
cd /path/to/Production-v2
cd terraform/environments/prod/infra
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
# Edit backend.hcl and terraform.tfvars with your real bucket, account, key pair,
# admin principal, CIDR, and DB settings. Never commit these local files.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out=infra.tfplan
terraform apply infra.tfplan
```

Keep the same S3 backend bucket/key that you intend to use for future plans. If the old state was deleted, verify the AWS account has no leftover resources with the same names before applying.

## 2. Connect to the new cluster

```bash
cd /path/to/Production-v2
CLUSTER_NAME="$(terraform -chdir=terraform/environments/prod/infra output -raw eks_cluster_name)"
aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME"
kubectl get nodes -o wide
```

Wait until the managed nodes report `Ready` before moving on.

## 3. Apply EKS add-ons, Prometheus, and Grafana

The add-ons Terraform root reads the infrastructure state. The monitoring release creates a private `monitoring` namespace, a Grafana credential Secret, and the pinned `kube-prometheus-stack` Helm release. Prometheus and Grafana data use the existing encrypted `ebs-gp3` StorageClass.

```bash
cd /path/to/Production-v2
cd terraform/environments/prod/addons
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
# Set state_bucket in terraform.tfvars and ensure infra_state_key matches the
# key used in step 1. Do not add the Grafana password to terraform.tfvars.
read -rsp "Choose a Grafana admin password (16+ chars): " TF_VAR_grafana_admin_password
echo
export TF_VAR_grafana_admin_password
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out=addons.tfplan
terraform apply addons.tfplan
unset TF_VAR_grafana_admin_password
```

Terraform state contains the Kubernetes Secret value. Keep the S3 state bucket encrypted, versioned, and tightly restricted. Store the Grafana password in your password manager.

## 4. Build and publish the application image

The rebuilt NGINX image enables a loopback-only `stub_status` endpoint. The exporter sidecar in the Pod reads it and exposes Prometheus metrics on the internal Service port 9113.

```bash
cd /path/to/Production-v2
IMAGE_TAG="nginx-metrics-1"
bash scripts/build-push-production-app.sh "$IMAGE_TAG"
```

Use a new immutable tag for each build. Do not reuse `latest` or an existing release tag.

## 5. Deploy the production Kubernetes YAML through Terraform

```bash
cd /path/to/Production-v2
IMAGE_TAG="nginx-metrics-1"
cd terraform/environments/prod/workloads
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to set state_bucket to the same bucket used by the
# infrastructure and add-ons roots. Keep the matching key in backend.hcl.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -var="image_tag=$IMAGE_TAG" -out=workloads.tfplan
terraform apply workloads.tfplan

kubectl rollout status deployment/nginx -n production
kubectl get pods,svc -n production
```

The first apply leaves NetworkPolicy disabled. Check the app and monitoring pods, then enable the policy with a second Terraform plan/apply. The policy permits VPC-A traffic to the web port and Prometheus in the monitoring namespace to scrape the exporter port.

```bash
terraform plan -var="image_tag=$IMAGE_TAG" -var='enable_network_policy=true' -out=network-policy.tfplan
terraform apply network-policy.tfplan
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
```

Verify the exporter and Prometheus target:

```bash
kubectl port-forward -n production svc/nginx-service 9113:9113
# In a second WSL terminal:
curl -fsS http://127.0.0.1:9113/metrics | head
```

In a separate terminal, check the Prometheus target:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://127.0.0.1:9090/targets and check production-nginx is UP.
```

Open Grafana privately:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Then visit `http://127.0.0.1:3000`, sign in as `admin`, and use the password entered in step 3. Do not create a public Ingress for Grafana or Prometheus.

## 6. Recreate Jenkins CI/CD in WSL

Install/start Jenkins in WSL as you prefer. Create a Pipeline-from-SCM job using `jenkins/Jenkinsfile.production-app` as its Script Path. Add an AWS credential with ID `aws-production-deployer` and a Secret Text credential with ID `terraform-state-bucket`. The AWS identity needs ECR push access, read/write/lock access to the Terraform state bucket, `eks:DescribeCluster`, and the EKS access entry configured in `terraform/environments/prod/infra/access.tf`. Use a dedicated role for Jenkins; do not reuse a personal access key. The pipeline asks for approval before applying the production plan.

The repository's root `Jenkinsfile` remains the CI pipeline for the Voting application. The new pipeline handles the production NGINX app in `app/`; it builds/pushes a unique image tag and deploys the YAML through Terraform.

## 7. Destroy safely

Destroy application workloads and EKS add-ons before the EKS cluster, then destroy AWS infrastructure. Keep the Terraform state bucket. Before destroying monitoring, export any dashboards you created manually; Helm-managed default dashboards can be recreated from the chart.
