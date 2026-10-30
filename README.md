# Production-v2

Production-style AWS + Amazon EKS project that separates **AWS infrastructure**, **EKS platform add-ons**, and **Kubernetes workloads** into independent layers.

The repository is designed as a practical DevOps reference for building, deploying, operating, and troubleshooting a multi-AZ AWS/EKS environment with Terraform, Helm, Docker, and native Kubernetes YAML.

> The original `Production` repository is intentionally kept unchanged so the older implementation can be compared with this refactored `Production-v2` architecture.

> **Latest verified progress (30 October 2026):** Integrated Jenkins CI/CD Build #2 published and deployed `ci-2-4f82d39` to the isolated EKS preview, with manual approval, scoped RBAC, Rolling Update and automated HTTP verification all passing. An intentionally failed image rollout was also recovered by rollback. Terraform provisioning through Jenkins is **planned, not yet implemented**. [Read October 30 update](#october-30-2026--integrated-jenkins-cicd-and-eks-preview-release).

---

## Table of Contents

- [Project Goals](#project-goals)
- [High-Level Architecture](#high-level-architecture)
- [Repository Structure](#repository-structure)
- [Architecture Layers](#architecture-layers)
- [Network Architecture](#network-architecture)
- [EKS Architecture](#eks-architecture)
- [EKS Managed Add-ons](#eks-managed-add-ons)
- [AWS Load Balancer Controller](#aws-load-balancer-controller)
- [Application Request Flow](#application-request-flow)
- [Kubernetes Workloads](#kubernetes-workloads)
- [Storage and Stateful Workloads](#storage-and-stateful-workloads)
- [Secrets and IRSA](#secrets-and-irsa)
- [RDS and Data Services](#rds-and-data-services)
- [Disaster Recovery Foundation](#disaster-recovery-foundation)
- [Terraform State Design](#terraform-state-design)
- [Deployment Order](#deployment-order)
- [Verification](#verification)
- [Troubleshooting Lessons](#troubleshooting-lessons)
- [Security Design](#security-design)
- [Production Improvements](#production-improvements)
- [Example Voting Application on Amazon EKS](#example-voting-application-on-amazon-eks)
- [October 29, 2026 — CI and EKS Preview Validation](#october-29-2026--jenkins-ci-amazon-ecr-and-eks-preview-validation)
- [October 30, 2026 — Integrated Jenkins CI/CD and EKS Preview Release](#october-30-2026--integrated-jenkins-cicd-and-eks-preview-release)

---

# Project Goals

The main goal of `Production-v2` is to demonstrate a cleaner production-style separation of responsibilities.

```text
Terraform Infrastructure
        |
        v
Terraform EKS Add-ons
        |
        v
Vendor Platform Software
        |
        v
Native Kubernetes Workloads
```

The design follows these rules:

- `terraform/environments/prod/infra` manages AWS infrastructure.
- `terraform/environments/prod/addons` manages EKS add-ons and IAM/IRSA.
- Helm installs vendor software such as AWS Load Balancer Controller.
- Kubernetes YAML manages application workloads and Kubernetes-native objects.
- Terraform does not manage application Deployments, Services, Ingresses, StatefulSets, Jobs, or CronJobs.

This keeps the project easier to understand, troubleshoot, and maintain.

---

# High-Level Architecture

```mermaid
flowchart TB

    USER[Internet User]

    subgraph AWS1["AWS Region: us-east-1"]

        subgraph VPCA["VPC-A - 10.10.0.0/16"]

            IGW[Internet Gateway]

            subgraph PUB["Public Subnets"]
                PUB1["10.10.1.0/24\nus-east-1a"]
                PUB2["10.10.3.0/24\nus-east-1b"]
                BASTION[Bastion Host]
                NAT[NAT Gateway]
                ALB[Application Load Balancer]
            end

            subgraph PRIV["Private Subnets"]
                PRIV1["10.10.2.0/24\nus-east-1a"]
                PRIV2["10.10.4.0/24\nus-east-1b"]

                subgraph EKS["Amazon EKS"]
                    FRONTEND["Dedicated Frontend Node Group"]
                    GENERAL["General Node Group"]
                    NGINX["Nginx Deployment"]
                    STATEFUL["StatefulSet"]
                    OPS["DaemonSet / Jobs / CronJob"]
                end

                RDS[(Amazon RDS MySQL)]
            end

            TGWA["TGW Subnet\n10.10.10.0/28"]
            S3EPA[S3 Gateway Endpoint]
        end

        subgraph VPCB["VPC-B - 10.20.0.0/16"]
            PRIVB["Private Subnet\n10.20.2.0/24"]
            EC2B[Private EC2]
            TGWB["TGW Subnet\n10.20.10.0/28"]
            S3EPB[S3 Gateway Endpoint]
        end

        TGW[Transit Gateway]
        ECR[(Amazon ECR)]
        S3[(Amazon S3)]
        SECRETS[AWS Secrets Manager]
    end

    subgraph AWS2["DR Region: us-west-2"]
        DRVPC[DR VPC]
        KMS[AWS KMS]
        DRRDS[Optional RDS DR Resources]
    end

    USER --> ALB
    ALB --> NGINX

    NGINX --> SECRETS
    NGINX --> RDS
    EKS --> ECR

    PRIV --> NAT
    NAT --> IGW

    TGWA --> TGW
    TGWB --> TGW

    S3EPA --> S3
    S3EPB --> S3

    RDS -. Optional DR .-> DRRDS
    DRRDS --> KMS
    DRRDS --> DRVPC
```

---

# Repository Structure

```text
Production-v2/
├── README.md
├── SETUP.md
├── .gitignore
│
├── app/
│   ├── Dockerfile
│   └── index.html
│
├── scripts/
│   ├── install-alb-controller.sh
│   ├── deploy-kubernetes.sh
│   └── verify.sh
│
├── terraform/
│   ├── modules/
│   │   ├── alb-controller-iam/
│   │   ├── bastion/
│   │   ├── ec2/
│   │   ├── ecr/
│   │   ├── eks/
│   │   ├── eks-secrets-access/
│   │   ├── iam-ec2-s3/
│   │   ├── rds/
│   │   ├── rds-dr/
│   │   ├── s3/
│   │   ├── transit-gateway/
│   │   ├── vpc/
│   │   └── vpc-endpoint/
│   │
│   └── environments/
│       └── prod/
│           ├── infra/
│           │   ├── backend.tf
│           │   ├── backend.hcl.example
│           │   ├── providers.tf
│           │   ├── variables.tf
│           │   ├── terraform.tfvars.example
│           │   ├── locals.tf
│           │   ├── network.tf
│           │   ├── compute.tf
│           │   ├── data-services.tf
│           │   ├── eks.tf
│           │   ├── access.tf
│           │   ├── ecr.tf
│           │   ├── dr.tf
│           │   └── outputs.tf
│           │
│           └── addons/
│               ├── backend.tf
│               ├── backend.hcl.example
│               ├── providers.tf
│               ├── variables.tf
│               ├── terraform.tfvars.example
│               ├── data.tf
│               ├── locals.tf
│               ├── core-addons.tf
│               ├── vpc-cni.tf
│               ├── ebs-csi.tf
│               ├── secrets-csi.tf
│               ├── metrics-server.tf
│               ├── app-secrets-irsa.tf
│               ├── alb-controller-iam.tf
│               └── outputs.tf
│
└── kubernetes/
    ├── addons/
    │   └── aws-load-balancer-controller-serviceaccount.yaml
    │
    └── prod/
        ├── 00-namespace/
        │   └── namespace.yaml
        │
        ├── 01-security/
        │   ├── serviceaccounts.yaml
        │   ├── rbac.yaml
        │   └── secret-provider-class.yaml
        │
        ├── 02-storage/
        │   └── storage-class.yaml
        │
        ├── 03-application/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   ├── ingress.yaml
        │   ├── hpa.yaml
        │   └── pdb.yaml
        │
        ├── 04-stateful/
        │   ├── headless-service.yaml
        │   └── statefulset.yaml
        │
        ├── 05-operations/
        │   ├── daemonset.yaml
        │   ├── job.yaml
        │   └── cronjob.yaml
        │
        └── 06-network-policy/
            └── network-policy.yaml
```

---

# Architecture Layers

## 1. Terraform Infrastructure Layer

Directory:

```text
terraform/environments/prod/infra
```

This layer creates the AWS infrastructure.

It manages:

- VPC-A
- VPC-B
- public and private subnets
- Internet Gateway
- NAT Gateway
- route tables
- Transit Gateway
- S3 Gateway Endpoints
- Bastion host
- private EC2 instances
- IAM roles
- Amazon ECR
- Amazon S3
- Amazon RDS MySQL
- Amazon EKS
- EKS managed node groups
- EKS OIDC provider
- EKS access
- DR foundation in `us-west-2`
- KMS resources for DR

This Terraform root intentionally uses AWS providers only for infrastructure responsibilities.

---

## 2. Terraform EKS Add-ons Layer

Directory:

```text
terraform/environments/prod/addons
```

The add-ons layer reads infrastructure outputs through Terraform remote state.

It manages:

- CoreDNS
- kube-proxy
- Amazon VPC CNI
- Amazon EBS CSI Driver
- AWS Secrets Store CSI Driver Provider
- Metrics Server
- EBS CSI IAM role
- application Secrets Manager IAM role
- AWS Load Balancer Controller IAM role and policy

Dependency flow:

```text
Infrastructure Terraform State
          |
          | outputs
          v
EKS Add-ons Terraform State
```

This makes add-ons independently manageable without mixing them into the main infrastructure state.

---

## 3. Vendor Platform Software Layer

AWS Load Balancer Controller is installed with Helm.

Script:

```text
scripts/install-alb-controller.sh
```

Terraform creates the IAM role and policy.

Helm installs the controller into:

```text
namespace: kube-system
serviceAccount: aws-load-balancer-controller
```

IRSA connects the Kubernetes ServiceAccount to the AWS IAM role.

---

## 4. Kubernetes Workload Layer

Directory:

```text
kubernetes/prod
```

Native Kubernetes YAML manages:

- Namespace
- ServiceAccounts
- RBAC
- SecretProviderClass
- StorageClass
- Deployment
- Service
- Ingress
- HPA
- PDB
- StatefulSet
- Headless Service
- DaemonSet
- Job
- CronJob
- NetworkPolicy

---

# Network Architecture

## VPC-A

Primary application VPC:

```text
CIDR: 10.10.0.0/16
```

| Subnet | CIDR | AZ | Purpose |
|---|---|---|---|
| Public Subnet 1 | `10.10.1.0/24` | `us-east-1a` | Public networking / ALB / NAT |
| Public Subnet 2 | `10.10.3.0/24` | `us-east-1b` | Multi-AZ ALB |
| Private Subnet 1 | `10.10.2.0/24` | `us-east-1a` | EKS private workloads |
| Private Subnet 2 | `10.10.4.0/24` | `us-east-1b` | EKS private workloads |
| TGW Subnet | `10.10.10.0/28` | `us-east-1a` | Transit Gateway attachment |

Public subnets are tagged:

```text
kubernetes.io/role/elb = 1
```

Private subnets are tagged:

```text
kubernetes.io/role/internal-elb = 1
```

These tags allow AWS Load Balancer Controller to discover appropriate subnets.

---

## VPC-B

Secondary private VPC:

```text
CIDR: 10.20.0.0/16
```

It contains:

- private EC2 workload
- private subnet
- Transit Gateway subnet
- S3 Gateway Endpoint

VPC-A and VPC-B communicate through AWS Transit Gateway.

```text
VPC-A
  |
  | TGW attachment
  v
Transit Gateway
  ^
  | TGW attachment
  |
VPC-B
```

---

## Internet Access

Public resources use the Internet Gateway.

Private workloads use:

```text
Private Subnet
      |
      v
Private Route Table
      |
      v
NAT Gateway
      |
      v
Internet Gateway
      |
      v
Internet
```

The lab currently uses a shared NAT Gateway.

For stricter production high availability, use one NAT Gateway per AZ with AZ-specific private route tables.

---

# EKS Architecture

Cluster:

```text
production-eks-cluster
```

EKS worker nodes run in VPC-A private subnets.

## General-Purpose Node Group

Current configuration:

```text
Instance Type: t3.small
Min Size:      2
Desired Size:  3
Max Size:      4
Capacity Type: ON_DEMAND
```

This node group is used for:

- Kubernetes system components
- StatefulSet workloads
- Jobs
- CronJobs
- DaemonSets
- other general workloads

---

## Dedicated Frontend Node Group

Current configuration:

```text
Instance Type: t3.small
Min Size:      1
Desired Size:  1
Max Size:      2
```

Labels:

```text
workload=frontend
environment=production
```

Taint:

```text
dedicated=frontend:NoSchedule
```

The nginx Deployment uses matching node affinity and toleration.

```text
Nginx Pods
   |
   v
nodeAffinity: workload=frontend
   |
   v
toleration: dedicated=frontend
   |
   v
Dedicated Frontend Node
```

This demonstrates workload isolation.

---

# EKS Managed Add-ons

Terraform manages these EKS add-ons:

| Add-on | Purpose |
|---|---|
| VPC CNI | Pod networking and VPC IP allocation |
| CoreDNS | Kubernetes DNS |
| kube-proxy | Kubernetes Service networking |
| EBS CSI Driver | Dynamic EBS persistent volumes |
| Secrets Store CSI Provider | AWS Secrets Manager integration |
| Metrics Server | CPU and memory metrics |

The add-on versions are pinned in Terraform for reproducibility.

---

# AWS Load Balancer Controller

The AWS Load Balancer Controller watches Kubernetes Ingress resources and provisions AWS load balancers.

Flow:

```text
Ingress YAML
    |
    v
AWS Load Balancer Controller
    |
    v
AWS ALB
    |
    v
Target Group
    |
    v
Kubernetes Pod IPs
```

The project uses:

```text
Scheme:      internet-facing
Target Type: ip
Listener:    HTTP 80
Health Path: /
IngressClass: alb
```

The controller IAM permissions are created through Terraform and accessed with IRSA.

---

# Application Request Flow

Main request path:

```text
Internet User
      |
      v
AWS Application Load Balancer
      |
      v
Kubernetes Ingress
      |
      v
ClusterIP Service: nginx-service
      |
      v
Nginx Deployment
      |
      +--> Pod 1
      +--> Pod 2
      +--> Pod 3
```

The Ingress uses:

```yaml
ingressClassName: alb
```

and:

```text
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
```

With `target-type: ip`, the ALB registers Pod IP addresses directly in the target group.

---

# Kubernetes Workloads

## Nginx Deployment

The application Deployment uses:

```text
Replicas: 3
Strategy: RollingUpdate
```

It includes:

- CPU requests
- memory requests
- CPU limits
- memory limits
- readiness probe
- liveness probe
- node affinity
- pod anti-affinity
- frontend toleration
- Secrets Store CSI volume

---

## ClusterIP Service

```text
nginx-service
```

The Service provides a stable Kubernetes endpoint in front of the nginx Pods.

```text
Ingress
   |
   v
nginx-service
   |
   v
Nginx Pods
```

---

## Horizontal Pod Autoscaler

The application uses HPA:

```text
Minimum Pods: 3
Maximum Pods: 6
CPU Target:   60%
```

Metrics Server supplies resource metrics.

Useful commands:

```bash
kubectl get hpa -n production
kubectl top pods -n production
kubectl top nodes
```

---

## Pod Disruption Budget

The application uses a PDB to protect availability during voluntary disruptions.

```text
minAvailable: 2
```

With three nginx replicas, Kubernetes attempts to keep at least two Pods available during operations such as node draining.

---

## DaemonSet

`node-observer` demonstrates one Pod per eligible Kubernetes node.

Typical real-world uses include:

- log agents
- monitoring agents
- security agents
- node collectors

---

## Job

`nginx-smoke-test` performs a one-time connectivity check:

```text
Job
 |
 v
wget http://nginx-service
 |
 v
Application Service
```

---

## CronJob

`nginx-health-check` runs periodically:

```text
*/15 * * * *
```

It validates Service connectivity on a schedule.

---

# Storage and Stateful Workloads

## EBS StorageClass

The project uses EBS CSI with:

```text
Provisioner: ebs.csi.aws.com
Volume Type: gp3
Encrypted:   true
Binding:     WaitForFirstConsumer
```

`WaitForFirstConsumer` ensures the EBS volume is created after Kubernetes has selected an appropriate node topology.

---

## StatefulSet

The StatefulSet demonstrates:

- stable Pod identities
- Headless Service
- persistent storage
- per-Pod PVCs
- EBS-backed persistence

Example:

```text
stateful-web-0
   |
   v
web-data-stateful-web-0
   |
   v
EBS Volume

stateful-web-1
   |
   v
web-data-stateful-web-1
   |
   v
EBS Volume
```

Amazon EBS volumes are Availability-Zone specific.

A Pod must therefore run on a node in the same AZ as its EBS volume.

---

# Secrets and IRSA

The database password is not stored in Git.

RDS uses AWS Secrets Manager for its master credentials.

Application secret flow:

```text
AWS Secrets Manager
        |
        v
Secrets Store CSI Driver
        |
        v
SecretProviderClass
        |
        v
Mounted read-only secret volume
        |
        v
Application Pod
```

The application ServiceAccount uses an IRSA role with permission only to the required secret.

---

## IRSA Relationships

```text
EBS CSI ServiceAccount
      |
      v
EBS CSI IAM Role

AWS Load Balancer Controller ServiceAccount
      |
      v
ALB Controller IAM Role

production-app ServiceAccount
      |
      v
App Secrets IAM Role
```

The EKS OIDC provider enables these trust relationships.

---

# RDS and Data Services

## Amazon RDS

The project uses RDS MySQL in private subnets.

Key design points:

- DB subnet group across private subnets
- security group-controlled access
- Secrets Manager master credentials
- private networking
- Terraform-managed configuration
- parameter group support
- backup configuration

The lab uses cost-conscious defaults.

For a stricter production environment, consider:

- Multi-AZ
- deletion protection
- longer backup retention
- enhanced monitoring
- Performance Insights
- automated DR

---

## Amazon S3

S3 is used for application/lab data.

S3 Gateway Endpoints allow private VPC resources to access S3 without using public internet routing.

---

## Amazon ECR

Application container images are stored in Amazon ECR.

Flow:

```text
Docker Build
     |
     v
Amazon ECR
     |
     v
EKS Image Pull
     |
     v
Application Pod
```

---

# Disaster Recovery Foundation

The repository includes an optional DR foundation in:

```text
us-west-2
```

It supports future RDS disaster recovery features.

The DR layer includes:

- DR VPC
- private subnets
- RDS DR networking
- security controls
- KMS key

Optional Terraform flags can enable additional DR resources such as:

- cross-region read replica
- cross-region backups
- snapshot workflows
- Performance Insights

These are disabled by default to control lab cost.

---

# Terraform State Design

The repository uses separate Terraform state files.

## Infrastructure State

```text
production-v2/infra/terraform.tfstate
```

Contains AWS infrastructure state.

## Add-ons State

```text
production-v2/addons/terraform.tfstate
```

Contains EKS platform add-ons and IAM/IRSA state.

The add-ons layer reads infrastructure outputs with:

```hcl
data "terraform_remote_state" "infra"
```

Dependency:

```text
Infra State
    |
    | cluster name
    | VPC ID
    | OIDC provider
    | RDS secret ARN
    v
Add-ons Layer
```

The S3 backend uses native Terraform locking:

```hcl
use_lockfile = true
```

---

# Git and Sensitive Files

The repository intentionally ignores sensitive/local Terraform files.

Do not commit:

```text
backend.hcl
terraform.tfvars
*.tfstate
*.tfstate.*
tfplan
.terraform/
.env
*.pem
*.key
```

Commit:

```text
*.tf
*.example
.terraform.lock.hcl
Kubernetes YAML
scripts
README.md
SETUP.md
```

Never commit AWS access keys, database credentials, private keys, or secret values.

---

# Deployment Order

The recommended build order is:

```text
1. Clone Repository
        |
        v
2. Configure Terraform Infra
        |
        v
3. Apply AWS Infrastructure
        |
        v
4. Configure kubectl
        |
        v
5. Apply EKS Add-ons
        |
        v
6. Install AWS Load Balancer Controller
        |
        v
7. Build + Push Docker Image to ECR
        |
        v
8. Deploy Kubernetes YAML
        |
        v
9. Verify Application
        |
        v
10. Apply NetworkPolicy
```

---

## 1. Clone

```bash
git clone https://github.com/SubhamPanwarr/Production-v2.git
cd Production-v2
```

---

## 2. Infrastructure Terraform

```bash
cd terraform/environments/prod/infra

cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Initialize:

```bash
terraform init -backend-config=backend.hcl
```

Validate:

```bash
terraform fmt -recursive
terraform validate
```

Plan:

```bash
terraform plan -out=tfplan
```

Apply:

```bash
terraform apply tfplan
```

---

## 3. Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name production-eks-cluster
```

Verify:

```bash
kubectl get nodes -o wide
```

---

## 4. EKS Add-ons Terraform

```bash
cd ../addons

cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Initialize:

```bash
terraform init -backend-config=backend.hcl
```

Validate and plan:

```bash
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Apply:

```bash
terraform apply tfplan
```

Verify:

```bash
aws eks list-addons \
  --cluster-name production-eks-cluster \
  --region us-east-1 \
  --output table
```

---

## 5. Install AWS Load Balancer Controller

From repository root:

```bash
cd ~/Production-v2
```

Update Helm:

```bash
helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo update
```

List available chart versions:

```bash
helm search repo eks/aws-load-balancer-controller --versions | head
```

Set a tested version:

```bash
export AWS_LBC_CHART_VERSION="3.6.1"
export AWS_REGION="us-east-1"
```

Install:

```bash
chmod +x scripts/install-alb-controller.sh
./scripts/install-alb-controller.sh
```

Verify:

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system

kubectl get pods \
  -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## 6. Build and Push Application Image

Get ECR URL:

```bash
export ECR_REPOSITORY_URL=$(
  terraform -chdir=terraform/environments/prod/infra \
  output -raw ecr_repository_url
)

export IMAGE_TAG=v2
```

Login:

```bash
aws ecr get-login-password \
  --region us-east-1 \
  | docker login \
      --username AWS \
      --password-stdin \
      "$(echo "$ECR_REPOSITORY_URL" | cut -d/ -f1)"
```

Build:

```bash
docker build \
  -t production-app:$IMAGE_TAG \
  app/
```

Tag:

```bash
docker tag \
  production-app:$IMAGE_TAG \
  "$ECR_REPOSITORY_URL:$IMAGE_TAG"
```

Push:

```bash
docker push "$ECR_REPOSITORY_URL:$IMAGE_TAG"
```

---

## 7. Deploy Kubernetes Resources

```bash
chmod +x scripts/deploy-kubernetes.sh scripts/verify.sh

IMAGE_TAG=v2 ./scripts/deploy-kubernetes.sh
```

The deployment script applies:

```text
00-namespace
01-security
02-storage
03-application
04-stateful
05-operations
```

NetworkPolicy is intentionally applied later.

---

# Verification

## Cluster

```bash
kubectl get nodes -o wide
kubectl get nodes -L topology.kubernetes.io/zone,workload
```

## Workloads

```bash
kubectl get all -n production
kubectl get pods -n production -o wide
```

## Storage

```bash
kubectl get pvc -n production
kubectl get pv
```

## HPA

```bash
kubectl get hpa -n production
kubectl top pods -n production
kubectl top nodes
```

## ALB

```bash
kubectl get ingress -n production
```

Get DNS name:

```bash
ALB_DNS=$(kubectl get ingress production-app-ingress \
  -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "$ALB_DNS"
```

Test:

```bash
curl -I "http://$ALB_DNS"
curl "http://$ALB_DNS"
```

Expected:

```text
HTTP/1.1 200 OK
```

---

# NetworkPolicy

The NetworkPolicy is intentionally applied after the application is healthy.

Current policy:

- selects nginx Pods
- allows TCP port 80
- allows ingress from VPC-A CIDR `10.10.0.0/16`

Apply:

```bash
kubectl apply \
  -f kubernetes/prod/06-network-policy/network-policy.yaml
```

Verify:

```bash
kubectl get networkpolicy -n production
```

Retest the ALB afterward.

---

# Troubleshooting Lessons

This project intentionally includes real troubleshooting scenarios encountered during deployment.

## 1. ALB Could Not Discover Subnets

Symptom:

```text
FailedBuildModel
couldn't auto-discover subnets
```

Checks:

```bash
aws ec2 describe-subnets \
  --filters \
    "Name=vpc-id,Values=<vpc-id>" \
    "Name=tag:kubernetes.io/role/elb,Values=1"
```

Also verify controller configuration:

```bash
kubectl get deployment aws-load-balancer-controller \
  -n kube-system \
  -o jsonpath='{.spec.template.spec.containers[0].args}'
```

Important lesson:

The controller region must match the EKS cluster region.

---

## 2. Pod Pending - Too Many Pods

Symptom:

```text
Too many pods
```

Check allocatable Pod count:

```bash
kubectl get nodes \
  -o custom-columns='NODE:.metadata.name,ALLOCATABLE-PODS:.status.allocatable.pods'
```

Count Pods per node:

```bash
for NODE in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "===== $NODE ====="

  kubectl get pods -A \
    --field-selector spec.nodeName="$NODE" \
    --no-headers | wc -l
done
```

Small EKS instances can hit Pod density limits quickly when platform DaemonSets are installed.

---

## 3. EC2 vCPU Quota

The general node group was scaled to:

```text
desired_size = 3
```

but a new node could not initially launch because the account had an 8-vCPU Standard On-Demand quota.

Check quota:

```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-1
```

A practical production/lab lesson:

Always validate EC2 service quotas before scaling EKS node groups.

Current planned compute:

```text
3 x general t3.small  = 6 vCPU
1 x frontend t3.small = 2 vCPU
1 x bastion t3.micro  = 2 vCPU
--------------------------------
Total                 = 10 vCPU
```

Request enough quota headroom before running all resources simultaneously.

---

## 4. StatefulSet Pending Due to EBS AZ Affinity

Symptom:

```text
node(s) didn't match PersistentVolume's node affinity
```

Amazon EBS volumes are AZ-specific.

Find PVC:

```bash
kubectl get pvc -n production -o wide
```

Find PV:

```bash
PV=$(kubectl get pvc <pvc-name> \
  -n production \
  -o jsonpath='{.spec.volumeName}')
```

Check required AZ:

```bash
kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[*].matchExpressions[*].values}{"\n"}'
```

Compare node AZs:

```bash
kubectl get nodes \
  -L topology.kubernetes.io/zone,workload
```

---

## 5. CNI IP Assignment

Possible symptom:

```text
failed to assign an IP address to container
```

Useful checks:

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
kubectl logs -n kube-system <aws-node-pod>
```

Also verify:

- subnet free IP addresses
- VPC CNI health
- node Pod density
- EC2 ENI/IP limits

---

# Security Design

The repository demonstrates:

- EKS worker nodes in private subnets
- RDS in private subnets
- security-group-controlled access
- IAM roles instead of static application credentials
- IRSA
- AWS Secrets Manager
- encrypted EBS volumes
- KMS for DR resources
- S3 Gateway Endpoints
- Kubernetes RBAC
- NetworkPolicy
- tainted dedicated node group
- remote Terraform state
- sensitive local Terraform configuration excluded from Git

---

# Production Improvements

This project balances production patterns with lab cost.

For a stricter production implementation, consider:

- one NAT Gateway per AZ
- separate private route tables per AZ
- larger EKS instance types
- custom networking / prefix delegation where appropriate
- Cluster Autoscaler or Karpenter
- higher EC2 service quotas
- Multi-AZ RDS
- deletion protection
- longer backup retention
- HTTPS with ACM
- Route 53
- AWS WAF
- ExternalDNS
- Prometheus + Grafana
- CloudWatch Container Insights
- centralized logging
- Trivy image scanning
- CI/CD with Jenkins or GitHub Actions
- admission policies
- Pod Security Standards
- ECR lifecycle policies
- AWS Backup
- automated multi-region DR

---

# Quick Architecture Summary

```text
GitHub
  |
  +--> Terraform Infrastructure
  |       |
  |       +--> VPC-A / VPC-B
  |       +--> Transit Gateway
  |       +--> Bastion / EC2
  |       +--> EKS
  |       +--> RDS
  |       +--> ECR
  |       +--> S3
  |       +--> DR Foundation
  |
  +--> Terraform EKS Add-ons
  |       |
  |       +--> VPC CNI
  |       +--> CoreDNS
  |       +--> kube-proxy
  |       +--> EBS CSI
  |       +--> Secrets Store CSI
  |       +--> Metrics Server
  |       +--> IAM / IRSA
  |
  +--> Helm
  |       |
  |       +--> AWS Load Balancer Controller
  |
  +--> Kubernetes YAML
          |
          +--> Namespace
          +--> RBAC
          +--> ServiceAccounts
          +--> Deployment
          +--> Service
          +--> Ingress
          +--> HPA
          +--> PDB
          +--> StatefulSet
          +--> DaemonSet
          +--> Job
          +--> CronJob
          +--> NetworkPolicy
```

Final application traffic flow:

```text
Internet User
      |
      v
AWS ALB
      |
      v
Kubernetes Ingress
      |
      v
ClusterIP Service
      |
      v
Nginx Pods
      |
      +--> AWS Secrets Manager via CSI + IRSA
      |
      +--> RDS MySQL
```

Persistent workload flow:

```text
StatefulSet
   |
   v
PVC
   |
   v
EBS CSI Driver
   |
   v
Encrypted gp3 EBS Volume
```

`Production-v2` provides a practical end-to-end reference for deploying and troubleshooting AWS infrastructure, Amazon EKS, platform add-ons, Kubernetes networking, storage, security, scaling, and application delivery.

---

## Example Voting Application on Amazon EKS

The [Docker Example Voting App](https://github.com/dockersamples/example-voting-app) is deployed on EKS as a multi-container training workload, separate from the Nginx platform lab documented earlier.

**Tested lab milestone (28 October 2026):** Vote and Result applications were exposed through public AWS ALBs, three Blue and three Green Vote replicas were healthy, and the Vote ALB successfully served **Blue → Green → Blue (rollback) → Green** using a Service selector. This describes the lab at the time of testing, not a continuous uptime guarantee.

### Application architecture

```text
Internet
  |----> Vote ALB ---> vote Ingress ---> vote Service ---> active Vote pods
  |                                                        |
  |                                                        v
  |                                                      Redis
  |                                                        |
  |                                                        v
  |                                                     Worker
  |                                                        |
  |                                                        v
  |                                                    PostgreSQL
  |
  +----> Result ALB ---> result Ingress ---> result Service ---> Result pods
                                                             |
                                                             +-- read PostgreSQL
```

Both ingresses use AWS Load Balancer Controller (`ingressClassName: alb`) with internet-facing ALBs and `alb.ingress.kubernetes.io/target-type: ip`, so the target groups register Pod IPs. Both public endpoints returned HTTP 200 in testing. The application components share Redis, Worker and PostgreSQL; **Blue-Green applies to the Vote frontend**, not two isolated full stacks.

| Component | Tested replicas | Role |
| --- | ---: | --- |
| Vote (Blue) | 3 | Existing frontend, retained for rollback |
| Vote (Green) | 3 | Updated frontend, active after final cutover |
| Result | 3 | Live voting results |
| Redis | 1 | Vote queue |
| Worker | 1 | Reads votes from Redis, writes PostgreSQL |
| PostgreSQL | 1 | Voting database; lab-only ephemeral storage |

### Repository layout

- `application/voting-app/` — application source and Dockerfiles
- `kubernetes/voting-app/base/` — Deployments and Services
- `kubernetes/voting-app/bluegreen/vote-green-deployment.yaml` — Green Deployment
- `kubernetes/voting-app/bluegreen/vote-green-preview-service.yaml` — Green preview Service (created in local workspace)
- `kubernetes/voting-app/ingress/` — Vote and Result public ALB Ingress manifests
- `terraform/environments/prod/addons/` — EKS add-ons and IAM/IRSA
- `scripts/install-alb-controller.sh` — Helm install for the AWS Load Balancer Controller

### Rolling update and troubleshooting

The original `vote-v1` image used the Dockerfile's development stage and expected a local Docker Compose bind mount. In EKS, `/usr/local/app/app.py` was missing and the Pods entered `CrashLoopBackOff`. Building the Dockerfile's `final` stage, pushing `production-app:vote-v2` to ECR and updating the Vote Deployment resolved the problem. Kubernetes created a new ReplicaSet and finished its rolling update. Result and Worker images used tags `result-v1` and `worker-v1`.

```bash
kubectl logs -n voting-app deployment/vote
kubectl rollout status deployment/vote -n voting-app
kubectl rollout history deployment/vote -n voting-app
kubectl get replicasets -n voting-app
```

### Blue-Green deployment — cutover and rollback verified

The `vote` Deployment has three Pods labelled `slot: blue`; the `vote-green` Deployment has three Pods labelled `slot: green`. Both use the working Vote image, but Green sets `OPTION_A=GREEN - Cats` and `OPTION_B=GREEN - Dogs` for easy visual identification. Future releases should use distinct, immutable image digests.

The production Service `vote` routes traffic to whichever `slot` its selector specifies. The existing public ALB Ingress remains unchanged, and Blue stays running for rollback.

**Verify Deployments and selectors:**

```bash
kubectl get deployments -n voting-app
kubectl get pods -n voting-app -l app=vote -L slot -o wide
kubectl get svc vote -n voting-app -o jsonpath='{.spec.selector}{"\n"}'
```

**Preview Green before changing production traffic:**

```bash
kubectl get endpointslices -n voting-app -l kubernetes.io/service-name=vote-green-preview
kubectl port-forward -n voting-app svc/vote-green-preview 8090:80
# From a separate terminal: curl http://localhost:8090
```

**Cut over Blue → Green:**

```bash
kubectl patch svc vote -n voting-app --type=merge \
  -p '{"spec":{"selector":{"app":"vote","slot":"green"}}}'

kubectl get endpointslices -n voting-app -l kubernetes.io/service-name=vote
VOTE_ALB=$(kubectl get ingress vote-ingress -n voting-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s "http://$VOTE_ALB" | grep GREEN
```

**Roll back Green → Blue:**

```bash
kubectl patch svc vote -n voting-app --type=merge \
  -p '{"spec":{"selector":{"app":"vote","slot":"blue"}}}'
curl -s "http://$VOTE_ALB" | grep -E 'Cats|Dogs'
```

The rollback returned the original Cats/Dogs page via the same public ALB. The lab subsequently switched back to Green. **ALB target registration, deregistration and health checks are asynchronous, so this cutover method does not guarantee zero downtime.** Inspect target health before declaring success in a production environment.

### Canary deployment — weighted ALB routing

Canary deployment was implemented using the existing AWS Vote ALB
and AWS Load Balancer Controller weighted forwarding actions.

The implementation uses:
- Stable Green: 3 Pods, selected by the `vote` Service
- Canary: 1 Pod, selected by the `vote-canary` Service
- An ALB weighted forward action in `vote-ingress.yaml`

Both target groups were verified healthy before introducing traffic.

**Traffic distribution test (100 requests):**

| Environment | Configured weight | Observed requests |
|---|---:|---:|
| Stable Green | 90% | 91 |
| Canary | 10% | 9 |
| Errors | — | 0 |

The observed result was consistent with the intended 90/10 split.
Weighted traffic distribution is probabilistic.

**Rollback:**

The Ingress weights were restored to:
- Stable Green: 100
- Canary: 0

The restored Ingress was applied and committed to GitHub.
A separate post-rollback ALB traffic check should confirm reconciliation.

**Important:** ALB routing reconciliation is asynchronous.
Canary promotion and rollback require application monitoring,
target health checks and verification before declaring success.

Canary manifests:
- `kubernetes/voting-app/canary/vote-canary-deployment.yaml`
- `kubernetes/voting-app/canary/vote-canary-service.yaml`
- `kubernetes/voting-app/ingress/vote-ingress.yaml`

### Scheduling / node-capacity lessons

The three general-purpose `t3.small` nodes hit their 11-Pod limits. Green could not fully schedule because the remaining frontend node was tainted `dedicated=frontend:NoSchedule`. Applying the following toleration resolved the pending Pods and rollout deadline:

```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: frontend
    effect: NoSchedule
```

All three Green Pods are currently placed on one node, a **single point of failure**. This cost-conscious lab demonstrates scheduling and tolerations, but a production deployment needs enough node capacity and cross-node / multi-AZ placement. Other observed issues: CNI IP assignment errors, `Too many pods`, `ProgressDeadlineExceeded`, and ALB target registration.

### Security and production caveats

- PostgreSQL uses ephemeral storage: use durable persistent storage or managed PostgreSQL before production.
- Never commit the lab's `kubernetes/voting-app/base/postgres-secret.yaml` or actual credentials.
- Public ALBs use HTTP in the lab; use HTTPS with ACM, appropriate DNS and security controls in production.
- This is frontend Blue-Green; Blue and Green share the same Redis, Worker and PostgreSQL services.
- The local WSL manifests may be newer than the GitHub `main` branch. Before pushing, ensure `base/vote-deployment.yaml` has the `slot: blue` **Pod template** label (preserve the immutable Deployment selector `app: vote`), `base/vote-service.yaml` selects the intended active `slot: green`, and the preview Service YAML is included. The README update alone does not deploy workloads or commit those files.

### Next milestones (historical October 29 snapshot; see current status below)

1. **Completed (29 October 2026):** Jenkins CI with SonarQube Cloud, Trivy, Docker build/smoke test, ECR publish and manual EKS preview validation.
2. **Next:** Jenkins-to-EKS IAM authentication, EKS access entries and namespace-scoped Kubernetes RBAC.
3. **Next:** Jenkins-controlled deployment with approval, rollout verification and rollback while preserving Blue/Green/Canary traffic control.
4. **Hardening:** Remediate HIGH security findings, improve node capacity and placement, persistent storage, secrets, HTTPS and monitoring.

---

## October 29, 2026 — Jenkins CI, Amazon ECR and EKS Preview Validation

**Status: CI and ECR publishing completed; EKS preview test passed; automated Jenkins-to-EKS CD remains pending.**

### Verified CI pipeline — Jenkins Build #9

The root `Jenkinsfile` was pushed on `main` at Git commit `c8ba1b2` (`ci: add Trivy security gate and ECR image push`). Jenkins job: `Production-v2-CICD`.

| Stage | Observed result |
| --- | --- |
| Checkout and repository validation | Passed |
| Python syntax check | Passed |
| Docker build (`--target final`) | Passed |
| Application smoke test | Passed |
| SonarQube Cloud analysis | Quality Gate passed; current scope is only `application/voting-app/vote/app.py` |
| Trivy HIGH/CRITICAL report | Report archived: Debian OS scan found 48 HIGH, 0 CRITICAL |
| Trivy CRITICAL gate | Passed; blocks ECR push on CRITICAL findings (`--exit-code 1`) |
| ECR authentication and push | Passed using Jenkins credential ID `aws-ecr-push` |
| ECR image digest verification | Passed |
| Post-build cleanup | Completed |

**Published immutable build tag:**

```text
523881172609.dkr.ecr.us-east-1.amazonaws.com/production-app:ci-9-c8ba1b2
```

**Digest:** `sha256:14fc951ad06a2c6a0a596bc76e2042a6eb9db88104cd672f134569fcc9194622`

```bash
aws ecr describe-images \
  --repository-name production-app \
  --image-ids imageTag=ci-9-c8ba1b2 \
  --region us-east-1 \
  --query 'imageDetails[0].{Tags:imageTags,Digest:imageDigest}' \
  --output json
```

> Security qualification: The Trivy CRITICAL gate passed, but 48 HIGH-severity Debian OS findings remain for remediation or documented risk assessment. A passing CRITICAL-only gate does not mean the image is production-approved. Broader SonarQube source coverage is also outstanding.

### Verified EKS preview test

- EKS cluster `production-eks-cluster`, region `us-east-1`: **ACTIVE**.
- Four Kubernetes worker nodes: **4/4 Ready**.
- Existing `voting-app` workloads: 13 Pods running, including Blue, Green and Canary; Vote and Result ALB ingress addresses provisioned.
- Live `vote`, `vote-green` and `vote-canary` Deployments still used image tag `vote-v2` during testing; the `vote` Service selected `app=vote,slot=green`.
- A temporary Pod `vote-ci9-preview` used the new ECR image and label `app=vote-ci9-preview`. This isolated the test from the live `vote` Service.

**Observed scheduling error:**

```text
0/4 nodes are available: 1 node(s) had untolerated taint(s), 3 Too many pods.
```

Three worker nodes had reached their Kubernetes Pod scheduling limits. The fourth was dedicated to frontend workloads with taint `dedicated=frontend:NoSchedule`. The preview Pod had no matching toleration.

**Solution:** Added this toleration to the *temporary preview Pod* without modifying existing Deployments or removing node taints:

```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: frontend
    effect: NoSchedule
```

The preview Pod then scheduled onto node `ip-10-10-2-219.ec2.internal`, became **1/1 Running**, and responded to `kubectl port-forward -n voting-app pod/vote-ci9-preview 8085:80`.

```text
HTTP/1.1 200 OK
Server: gunicorn
<title>Cats vs Dogs!</title>
Processed by container ID vote-ci9-preview
```

The temporary preview Pod was deleted after the test. **This proves ECR-to-EKS image pull and application HTTP startup, not automatic deployment or a live release.**

### Troubleshooting lessons (October 28–29)

| Challenge | Cause | Resolution / current status |
| --- | --- | --- |
| Local SonarQube slowed/froze WSL laptop | Contention with Jenkins/containers | Used SonarQube Cloud |
| Jenkins SonarQube installation mismatch | Jenkinsfile name differed from configured server name | Used `withSonarQubeEnv('SonarQube')` |
| Sonar JavaScript analyzer unresponsive | Resource pressure | Scoped successful scan to one Python file; broad coverage still pending |
| Trivy image inspection timeout | Docker image inspection timing out | `--image-src docker`, `--parallel 2`, `--timeout 15m` |
| `environment: command not found` in Bash | Jenkins Groovy `environment {}` block run as shell script | Placed block in `Jenkinsfile` |
| AWS Credentials not in Jenkins dropdown | AWS Credentials plugin unavailable | Installed plugin and stored credential `aws-ecr-push` |
| Preview Pod `Pending` | Three nodes `Too many pods`; one untolerated taint | Added temporary matching frontend toleration |
| Docker ECR login plaintext-config warning | Docker stored ECR login in Jenkins user's config | Pipeline logs out; isolated temporary `DOCKER_CONFIG` recommended |

### Remaining work to finish Jenkins-to-EKS CD (historical October 29 snapshot; see current status below)

1. **EKS authentication:** Check EKS access mode, give a dedicated Jenkins deployment identity `eks:DescribeCluster`, create EKS access entry and generate a temporary kubeconfig. Do not copy root's kubeconfig.
2. **Kubernetes RBAC:** Assign least-privilege permissions for deploying in `voting-app`; verify `kubectl` access under Jenkins. (`kubectl` is already installed for Jenkins, version v1.36.2; Jenkins user has no kubeconfig.)
3. **Security:** Review/remediate 48 HIGH findings, maintain blocking CRITICAL gate, expand SonarQube analysis to additional application files.
4. **Controlled deployment:** Add Jenkins CD stage using plain Kubernetes YAML or a controlled image update, without silently switching Blue/Green or Canary live traffic.
5. **Promotion controls:** Add manual approval, readiness/rollout checks, HTTP/ALB target health verification, and rollback for failed releases.
6. **Cluster capacity:** Resolve general node Pod-density limits and improve placement across nodes/AZs before production rolling deployments.
7. **Credential hardening and end-to-end test:** Use temporary Docker auth config and least-privilege IAM; validate a new Git commit through ECR publishing, approved EKS rollout and rollback.

**Architecture boundary:** Terraform manages AWS infrastructure and EKS add-ons; native Kubernetes YAML manages application resources; Jenkins should orchestrate application delivery without recreating AWS infrastructure.

---

## October 30, 2026 — Integrated Jenkins CI/CD and EKS Preview Release

**Status: VERIFIED — Integrated Jenkins CI/CD successfully builds, scans, pushes and deploys to an isolated EKS preview, then runs an automated internal HTTP application check.** This is a lab preview, not a production traffic promotion.

### Verified October 30 milestones

| Activity | Outcome |
| --- | --- |
| Jenkins EKS IAM authentication | Assumed `production-v2-jenkins-eks-deployer` and generated temporary kubeconfig |
| Scoped Kubernetes RBAC | Preview Deployment patch allowed; `vote` and `vote-green` patch denied |
| Jenkins standalone CD Rolling Update | Updated `vote-cd-preview` from `vote-v2` to `ci-9-c8ba1b2` successfully |
| Intentional invalid-image rollout | Timed out as expected, previous image was restored by Jenkins |
| Rollback recovery | `vote-cd-preview` returned to 1/1 Ready and HTTP 200 |
| Integrated CI/CD Build #1 | Published and deployed `ci-1-87234ee` successfully |
| Integrated CI/CD Build #2 | Published and deployed `ci-2-4f82d39`, checked HTTP response automatically; **SUCCESS** |
| Live Blue/Green/Canary | Image tags remained `vote-v2`; preview deployment did not alter live ALB routing |

> The intentional invalid-image test correctly produced Jenkins `FAILURE`, while the automated rollback successfully restored a healthy image. The new **HTTP-content-failure rollback branch** has not yet been intentionally exercised.

### Repo files and Git commits

- `Jenkinsfile` — original CI pipeline.
- `jenkins/Jenkinsfile.integrated` — combined build, scan, ECR publish, approval and EKS preview delivery pipeline.
- `kubernetes/voting-app/cd/vote-cd-preview.yaml` — isolated preview Deployment without public Ingress.
- `kubernetes/voting-app/cd/vote-cd-preview-service.yaml` — private ClusterIP Service for automated HTTP testing.
- `kubernetes/voting-app/rbac/jenkins-reader.yaml` — Jenkins read-only RBAC.
- `kubernetes/voting-app/rbac/jenkins-cd-preview.yaml` — restricts Deployment patching to `vote-cd-preview`.
- `kubernetes/voting-app/rbac/jenkins-preview-http-check.yaml` — scoped GET permission for the preview Service proxy.

| Commit | Purpose |
| --- | --- |
| `c74897c` | Add isolated EKS preview Deployment and restricted CD RBAC |
| `87234ee` | Add integrated Jenkins CI/CD pipeline |
| `4f82d39` | Add automated EKS preview HTTP health verification and recovery logic |

### End-to-end workflow

```text
GitHub feature/integrated-cicd
  -> Jenkins checkout and validation
  -> Python syntax check
  -> Docker build (final stage) and container smoke test
  -> SonarQube Cloud analysis (Quality Gate PASSED in observed builds)
  -> Trivy HIGH/CRITICAL vulnerability report and CRITICAL gate
  -> Amazon ECR push and digest verification
  -> Manual deployment approval
  -> Jenkins assumes dedicated EKS IAM role, builds temporary kubeconfig
  -> Kubernetes restricted RBAC checks
  -> Rolling Update of vote-cd-preview only
  -> Verify rollout and exact new image
  -> Kubernetes API Service-proxy HTTP content test
       |-- success -> Jenkins SUCCESS
       `-- failed rollout or failed HTTP marker -> attempt previous-image restore
```

Jenkins uses dynamic tags derived from the pipeline build number and Git commit, writing the exact published image URI into `ecr-image.txt` for the deployment stage. It does not hardcode the previous release's ECR image.

**Verified ECR images:**

```text
523881172609.dkr.ecr.us-east-1.amazonaws.com/production-app:ci-1-87234ee
523881172609.dkr.ecr.us-east-1.amazonaws.com/production-app:ci-2-4f82d39
```

**Build #2 ECR digest:** `sha256:1d77c70bc4fde64374cad7405137604beedd7fe4d5d5bcebc390c307f0a3e157`

### EKS security and verification

The Jenkins credential `aws-ecr-push` can assume the EKS role `arn:aws:iam::523881172609:role/production-v2-jenkins-eks-deployer`. That role has an EKS access entry associated with Kubernetes group `jenkins-voting-readers`. Jenkins uses a temporary `KUBECONFIG`, not a copied user/root kubeconfig.

The Kubernetes RBAC role for CD grants named-Deployment patch access to `vote-cd-preview`, while attempts to patch live `vote` and `vote-green` return `no`. Note that Kubernetes `resourceNames` limits which resource is patchable, not the fields inside it.

The automated HTTP test requests the internal Service proxy route:

```text
/api/v1/namespaces/voting-app/services/vote-cd-preview/proxy/
```

and checks for `Cats vs Dogs!` in the returned body. It makes up to five attempts. This verifies internal application content, **not** public ALB target health, DNS, TLS or external user traffic.

Verification commands:

```bash
kubectl get deployment vote-cd-preview -n voting-app -o wide
kubectl get pods -n voting-app -l app=vote-cd-preview -o wide
kubectl rollout history deployment/vote-cd-preview -n voting-app
kubectl get svc vote-cd-preview -n voting-app
kubectl get --raw /api/v1/namespaces/voting-app/services/vote-cd-preview/proxy/ | grep 'Cats vs Dogs!'
kubectl get deployments vote vote-green vote-canary -n voting-app \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
```

### Known gaps before production use

1. **HIGH vulnerabilities:** The Trivy Debian scan still showed 48 HIGH findings. The configured CRITICAL-only gate passing is not a security sign-off.
2. **SonarQube scope:** Only one Python source file was analyzed in the verified runs; expand coverage and enforce required quality policy consistently.
3. **HTTP failure recovery test:** Intentionally fail the *post-rollout HTTP content check* and confirm rollback restores the prior image and HTTP response. Only the invalid-image rollout failure path has been tested deliberately.
4. **Capacity:** General `t3.small` nodes have previously hit the 11-Pod limit; ensure headroom, multi-node spreading and multi-AZ resilience.
5. **Delivery model:** `kubectl set image` changes the running cluster but does not update the Git YAML image field. Introduce release manifests/GitOps to manage drift.
6. **Production safeguards:** Add monitoring, alerting, HTTPS, external ALB checks, and appropriate data durability and security controls before live rollout.
7. **Git workflow:** Review `feature/integrated-cicd` and merge it into `main` after testing and approval.

### Proposed next phase — Jenkins-driven Terraform infrastructure (NOT YET IMPLEMENTED)

The planned infrastructure pipeline will reuse existing Terraform modules and the **same S3 state bucket/key** currently managing the running environment:

```text
GitHub -> Jenkins Terraform init/validate/plan
       -> Review plan and explicit approval
       -> Terraform apply using existing S3 remote state
       -> Bootstrap EKS access, RBAC and initial Kubernetes manifests
       -> Run integrated application CI/CD
       -> ECR -> EKS preview -> internal HTTP verification
```

Use a dedicated least-privilege Terraform provisioning identity and securely stored environment variables. Never apply the existing full infrastructure configuration against a new empty state file: duplicate resources, state conflicts and costs can result. A brand-new cluster requires namespace, RBAC and workload bootstrap before the existing CD image-update stage can succeed.

Currently Jenkins executes on WSL Ubuntu; a Jenkins server/agent on EC2 or another managed host would eliminate dependence on manually starting Ubuntu. Neither Jenkins-driven infrastructure provisioning nor Jenkins hosting migration has been implemented yet.
