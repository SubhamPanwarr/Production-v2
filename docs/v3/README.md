# Production-v3 — Java Login Application CI/CD on Amazon EKS

![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20ECR%20%7C%20RDS-orange)
![Terraform](https://img.shields.io/badge/IaC-Terraform-844FBA)
![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-blue)
![Kubernetes](https://img.shields.io/badge/Deployment-Rolling%20Update-326CE5)

> **Project status (2 November 2026):** Jenkins build **#22** successfully passed CI/security checks, published `ci-22-d1be085` to Amazon ECR, and completed a rolling update on EKS. The application was then manually rolled back to build #16 and successfully restored to build #22. Both replicas became Ready and the ALB `/login` endpoint returned HTTP 200.

## 1. Project overview

Production-v3 is a hands-on, AWS-based DevOps project that delivers a Java login web application through a controlled Jenkins CI/CD pipeline to Amazon Elastic Kubernetes Service (EKS).

The project demonstrates:

- AWS infrastructure provisioned with reusable Terraform modules.
- Separation of Terraform infrastructure, Terraform add-ons, Kubernetes YAML, application source, and Jenkins pipeline code.
- A Java/Spring Boot application packaged as a WAR and run on Tomcat.
- Continuous integration with Maven unit tests, SonarCloud quality gate, Docker image validation, and Trivy vulnerability scanning.
- Versioned Docker image publishing to Amazon Elastic Container Registry (ECR).
- Manual approval and IAM/RBAC-controlled EKS deployment.
- Kubernetes rolling updates, rollout verification, and rollback.
- Amazon ALB ingress routing to two application Pods in separate worker nodes.
- Amazon RDS MySQL and AWS Secrets Manager integration via the Secrets Store CSI Driver.

**Repository:** [SubhamPanwarr/Production-v2](https://github.com/SubhamPanwarr/Production-v2)  
**Working branch:** `feature/v3-eks-deployment`  
**Jenkins pipeline definition:** [`jenkins/Jenkinsfile.java-ci`](../../jenkins/Jenkinsfile.java-ci) (relative path from `docs/v3/README.md`)

## 2. Architecture

```text
Developer / GitHub (feature/v3-eks-deployment)
                |
                v
        Jenkins CI/CD server
                |
  +-------------+-------------------------------------------+
  | Checkout -> Maven build + 10 tests                      |
  |          -> SonarCloud quality gate                     |
  |          -> Docker Buildx (jenkins-v3-buildkit)          |
  |          -> Docker image validation                     |
  |          -> Trivy HIGH/CRITICAL library scan            |
  +-------------+-------------------------------------------+
                |
                v
       Amazon ECR (versioned image)
                |
                v
         Manual approval gate
                |
                v
      IAM role assumption + EKS RBAC
                |
                v
        Amazon EKS (private subnets)
        Namespace: production-v3
                |
         Rolling Deployment
                |
     +----------+----------+
     |                     |
  Java Pod 1             Java Pod 2
  worker node A          worker node B
     |                     |
     +----------+----------+
                |
   ClusterIP Service (80 -> 8080)
                |
       ALB Ingress (HTTP :80)
                |
        /login HTTP 200

Application Pods -> RDS MySQL (private DB subnets)
Application Pods -> Secrets Store CSI -> AWS Secrets Manager
```

### Infrastructure and components

| Component | Implementation |
|---|---|
| AWS region | `us-east-1` |
| Network | VPC `10.30.0.0/16`, public/private/database subnets across two Availability Zones |
| Availability Zones | `us-east-1a`, `us-east-1b` |
| EKS cluster | `production-v3-eks` |
| EKS nodes | Terraform-managed node group, desired capacity of 2 |
| Kubernetes namespace | `production-v3` |
| Deployment / container | `java-login-app` / `java-login-app` |
| Service | `java-login-service`, ClusterIP port 80 to container port 8080 |
| Ingress | `java-login-ingress`, AWS Load Balancer Controller, IP targets |
| Load balancer | `production-v3-java-alb` |
| Image repository | `523881172609.dkr.ecr.us-east-1.amazonaws.com/production-v3-java-login` |
| Database | Amazon RDS MySQL, database `UserDB` |
| Secrets | AWS Secrets Manager secret `production-v3/java-login-app/db` mounted via CSI |
| Automation | Jenkins + Maven + SonarCloud + Docker Buildx + Trivy + AWS CLI + kubectl |

**Lab caveat:** The Terraform RDS configuration uses a single-AZ instance, no read replica, and lab-oriented deletion settings. This is **not** a fully hardened production HA/DR design.

## 3. Repository structure

```text
Production-v2/
├── application/
│   └── java-login-app/
│       ├── Dockerfile
│       ├── pom.xml
│       ├── compose.local.yaml
│       ├── database/schema.sql
│       └── src/
├── terraform/
│   ├── modules/
│   │   ├── v3-network/
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── eks-secrets-access/
│   │   └── alb-controller-iam/       # plus other reusable modules
│   └── environments/v3/
│       ├── infra/                    # VPC, EKS, RDS, outputs, backend
│       └── addons/                   # CSI/IAM, ALB controller IAM, Jenkins CD access
├── kubernetes/
│   └── v3/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── serviceaccount.yaml
│       │   └── secret-provider-class.yaml
│       ├── addons/
│       │   ├── alb-controller-serviceaccount.yaml
│       │   └── jenkins-cd-rbac.yaml
│       └── ingress/
│           └── java-login-ingress.yaml.tpl
├── jenkins/
│   └── Jenkinsfile.java-ci
└── docs/
    └── v3/
        └── README.md                # this documentation
```

**Important:** `terraform/environments/v3/infra` and `terraform/environments/v3/addons` are separate Terraform states. The add-ons layer reads outputs from the infrastructure state. Review dependencies and backend settings before applying either layer.

## 4. Prerequisites

- AWS credentials with the permissions required for the specific setup tasks.
- Terraform (project requires a version compatible with its providers/backends).
- AWS CLI v2, `kubectl`, Docker/Buildx, Maven, and Git.
- Java 21 available to the Jenkins job; the Dockerfile builds Java 17-targeted code and runs a Tomcat 11 Java 17 image.
- A Jenkins server/agent with the configured tools and access to the Docker daemon.
- A pre-created S3 Terraform backend with access and locking configured as required by your environment.
- An AWS Secrets Manager secret containing expected `username` and `password` JSON fields; do not store those values in Git.
- EKS authentication/authorization for administrative setup and Jenkins deployment access.
- An appropriate public-IP `/32` allowlist for the EKS API and the ALB ingress.

**Security:** Never commit AWS access keys, private keys, `terraform.tfvars`, actual `backend.hcl`, `.env.local`, database passwords, or unredacted Jenkins credentials.

## 5. Terraform setup (overview)

The repository includes example variable and backend files. Set your own account-appropriate backend configuration and public-IP allowlists. Do **not** apply these steps to an existing cluster without reviewing the Terraform plan and current state.

### 5.1 Infrastructure layer

```bash
cd ~/Production-v2/terraform/environments/v3/infra

cp -n backend.hcl.example backend.hcl
cp -n terraform.tfvars.example terraform.tfvars

# Edit backend.hcl and terraform.tfvars with your environment's values.
# In particular, replace the example public_access_cidrs with your current IP /32.

terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out=tfplan

# Review the plan carefully before an intentional first-time apply.
# terraform apply tfplan
```

### 5.2 Add-ons layer

After core infrastructure and prerequisite AWS secrets exist:

```bash
cd ~/Production-v2/terraform/environments/v3/addons

cp -n backend.hcl.example backend.hcl
# Edit backend.hcl to point to the existing add-ons backend.

terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=tfplan

# Review before applying changes.
# terraform apply tfplan
```

The add-ons code references the infrastructure remote state at `production-v3/infra/terraform.tfstate` and configures Jenkins CD IAM/EKS access and application secret access. Install/configure the required Kubernetes controllers and CSI components before applying the application manifests; Terraform IAM alone does not replace the in-cluster controllers.

### 5.3 Configure `kubectl`

```bash
aws eks update-kubeconfig \
  --name production-v3-eks \
  --region us-east-1

kubectl get nodes -o wide
kubectl get namespace production-v3
```

## 6. Kubernetes manifests and application

The plain Kubernetes YAML under `kubernetes/v3/` defines the ServiceAccount, CSI secret mount, Deployment, Service, and ingress. The application uses:

- **2 replicas**, with readiness, liveness, and startup probes on `/login`.
- **Requests:** 200m CPU and 512Mi memory; **limits:** 1000m CPU and 1Gi memory.
- **ServiceAccount + IAM role** to read the application database secret through AWS Secrets Manager / Secrets Store CSI.
- **ClusterIP Service** forwarding port `80` to application port `8080`.
- **ALB Ingress** with `/login` health checks and success code `200`.

For a fresh environment, verify all prerequisites, namespace, controller installation, and secrets before applying manifests. The ingress file is a **template**, so replace `__ADMIN_CIDR__` with the authorized public CIDR before applying it. Do not apply the `.tpl` file without rendering.

```bash
# Inspect the manifests first:
ls kubernetes/v3/base kubernetes/v3/addons kubernetes/v3/ingress
kubectl get deployment,service,ingress -n production-v3
```

### Local application build (optional)

```bash
cd ~/Production-v2/application/java-login-app
mvn -B -ntp clean verify

docker buildx build --platform linux/amd64 \
  --load -t java-login-app:local .
```

The `compose.local.yaml` file additionally requires non-committed local environment variables for MySQL credentials. Review and provide those locally before using Docker Compose.

## 7. Jenkins CI/CD pipeline

**Jenkins job:** `production-v3-java-ci`  
**Pipeline from SCM:** `jenkins/Jenkinsfile.java-ci`  
**Branch:** `feature/v3-eks-deployment`

| # | Pipeline stage | Purpose |
|---|---|---|
| 1 | Checkout | Fetch GitHub code and identify the Git commit |
| 2 | Verify Tools | Check Java, Maven, Docker, Trivy, AWS CLI, kubectl |
| 3 | EKS CD Preflight | Assume restricted deploy role; validate EKS availability and Kubernetes RBAC |
| 4 | Maven Build and Test | Run `mvn clean verify` and tests |
| 5 | SonarCloud Analysis | Perform static analysis and wait for the quality gate |
| 6 | Docker Build | Build WAR/Tomcat image using the dedicated BuildKit builder |
| 7 | Verify Docker Image | Confirm image/WAR exist and container runs as non-root user |
| 8 | Trivy Vulnerability Scan | Fail on detected HIGH/CRITICAL **library-package** vulnerabilities |
| 9 | Publish to ECR | Publish image tagged with Jenkins build number and short Git SHA |
| 10 | Approve EKS Deployment | Require manual approval before changing the Deployment |
| 11 | Deploy to EKS | Set image, wait for rollout, validate image, revert to previous image on failed rollout |

### Image tagging

```text
ci-<jenkins-build-number>-<7-character-git-sha>
Example: ci-22-d1be085
```

### Dedicated Docker builder

The local Jenkins Buildx builder was created using the `docker-container` driver:

```bash
sudo -u jenkins -H docker buildx inspect jenkins-v3-buildkit
```

The Docker build stage uses `docker buildx build --builder jenkins-v3-buildkit --platform linux/amd64 --progress=plain --load ...`. The `--load` flag makes the resulting image available to subsequent Jenkins stages. The project experienced intermittent Docker/BuildKit socket connection errors before a successful run; one successful run does not establish that the underlying host issue is permanently resolved.

### Jenkins credentials and deployment authorization

- `sonarcloud-token`: SonarCloud token (Jenkins Secret Text).
- `aws-ecr-publisher`: AWS key pair stored in Jenkins credentials for the ECR publisher user.
- Jenkins assumes `production-v3-jenkins-deploy-role` via AWS STS for EKS deployment.
- EKS access entries associate the role with Kubernetes group `production-v3-deployers`.
- Namespace Role and RoleBinding restrict access to the intended Deployment and rollout resources.

Do not paste credentials or temporary STS secrets into job logs or README files. The `docker` group is effectively privileged on the build host; use isolated agents for a real production environment.

## 8. Verified deployment results — 2 November 2026

| Check | Verified result |
|---|---|
| Jenkins full pipeline | Build **#22**: `SUCCESS` |
| Application tests | 10 run, 0 failures, 0 errors |
| SonarCloud | Quality gate passed |
| Image published to ECR | `ci-22-d1be085` |
| EKS rolling update | Completed successfully |
| Deployment | `java-login-app` in `production-v3` |
| Kubernetes replicas | 2/2 Ready, 0 restarts during verification |
| Pod placement | Two distinct EKS worker nodes |
| ALB target group | Both application targets healthy (`:8080`) |
| External application | `/login` returned HTTP `200` |
| Manual rollback exercise | Restored `ci-16-6e8135b`, then returned to `ci-22-d1be085` |
| Latest observed revision | Revision 4 after rollback/restore lab |

**Verified image:**

```text
523881172609.dkr.ecr.us-east-1.amazonaws.com/production-v3-java-login:ci-22-d1be085
```

**Observed ALB hostname:**

```text
production-v3-java-alb-463935518.us-east-1.elb.amazonaws.com
```

> The HTTP endpoint is IP-allowlisted and may not respond from other public IP addresses. It currently uses HTTP rather than HTTPS; **do not submit real usernames or passwords to this endpoint**.

## 9. Operational verification commands

```bash
# EKS deployment and Pod health
kubectl rollout status deployment/java-login-app \
  -n production-v3 --timeout=300s
kubectl get deployment,po,svc,ingress -n production-v3 -o wide

# Current container image
kubectl get deployment java-login-app -n production-v3 \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# Rollout history
kubectl rollout history deployment/java-login-app -n production-v3

# Inspect application events/logs
kubectl describe deployment java-login-app -n production-v3
kubectl logs -n production-v3 deployment/java-login-app --tail=100

# From an allowed public IP; do not send credentials over HTTP
curl -sS -o /dev/null -w 'HTTP Status: %{http_code}\n' \
  http://production-v3-java-alb-463935518.us-east-1.elb.amazonaws.com/login
```

### Check ALB target health

```bash
REGION=us-east-1
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region "$REGION" --names production-v3-java-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

for TG in $(aws elbv2 describe-target-groups \
  --region "$REGION" --load-balancer-arn "$ALB_ARN" \
  --query 'TargetGroups[].TargetGroupArn' --output text); do
  aws elbv2 describe-target-health \
    --region "$REGION" --target-group-arn "$TG" \
    --query 'TargetHealthDescriptions[].{IP:Target.Id,Port:Target.Port,State:TargetHealth.State}' \
    --output table
done
```

## 10. Rolling updates and rollback

### Manual rollback lab (performed successfully)

The following commands **change running workloads**. Use only in a non-production lab environment, with explicit authorization, and after confirming a healthy recovery image.

```bash
NS=production-v3
DEPLOY=java-login-app

# Record the current known-good image
CURRENT_IMAGE=$(kubectl get deployment "$DEPLOY" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "Saved image: $CURRENT_IMAGE"

# Review revisions before selecting a rollback target
kubectl rollout history deployment/"$DEPLOY" -n "$NS"

# Example lab: roll back to a verified earlier revision
# kubectl rollout undo deployment/"$DEPLOY" -n "$NS" --to-revision=<verified-revision>

# Restore the captured known-good image after the lab, if required
# kubectl set image deployment/"$DEPLOY" "java-login-app=$CURRENT_IMAGE" -n "$NS"
# kubectl rollout status deployment/"$DEPLOY" -n "$NS" --timeout=300s
```

The Jenkinsfile also contains a separate **failure-handling mechanism**: if a new rollout fails, the pipeline sets the Deployment image back to the previously recorded image and waits for the recovery rollout. **That automatic failure path has not yet been deliberately tested.**

### Git-manifest drift warning

As of the verified branch revision, `kubernetes/v3/base/deployment.yaml` still references the earlier `ci-16-6e8135b` image even though the running Deployment uses `ci-22-d1be085`. Jenkins modifies the live Deployment with `kubectl set image`; this does not update the source manifest or the `kubectl.kubernetes.io/last-applied-configuration` annotation.

Avoid blindly reapplying outdated YAML, which can revert the image. For ongoing operations, use one clear deployment source of truth (for example, an automated image-tag update to Git followed by declarative application, or a GitOps controller).

## 11. Troubleshooting lessons

| Symptom | Investigation / resolution direction |
|---|---|
| `forwarding Ping: no such job` during Docker build | Investigate Docker BuildKit session, daemon/socket health, and builder stability |
| `use of closed network connection` / socket `broken pipe` | Check Docker and BuildKit logs; distinguish connection failure from container restart/OOM |
| Docker succeeds manually but fails in Jenkins | Execute a small Docker-only Jenkins pipeline as the actual `jenkins` user |
| Cached build succeeds, uncached build untested | Rerun a disposable diagnostic with `--no-cache` |
| Jenkins cannot modify EKS Deployment | Check STS assumed role, EKS access entry, namespace RBAC, and `kubectl auth can-i` |
| Pod not Ready | Inspect startup/readiness probes, Pod events, image pull, resource limits, CSI mounts, and application logs |
| ALB returns 5xx | Check target-group health, ingress annotations, Service endpoints, listener rules, and application readiness |
| `kubectl apply` resets running image | Reconcile Git manifests with the intended deployed image |

## 12. Security and future improvements

This is an educational lab, **not yet a fully production-hardened deployment**. Priorities for further work:

1. Add **HTTPS/TLS** using an ACM certificate and ALB HTTPS listener, redirecting HTTP to HTTPS before handling real credentials.
2. Preserve restricted public ingress/EKS API allowlists and avoid exposing privileged endpoints.
3. Move build execution to a dedicated, isolated Jenkins agent and investigate intermittent Docker/WSL2 connection issues.
4. Pin tool/base-image versions and consider container digest pinning and broader vulnerability scanning (the current Trivy gate checks library packages, not all OS packages).
5. Establish a clear Git-managed desired image tag to prevent drift between YAML and the running Deployment.
6. Add automated post-deployment application smoke tests, monitoring, alerts, and an auditable rollback test.
7. For genuine production use, revisit database Multi-AZ, backup retention, deletion protection, snapshots, network controls, and disaster recovery.
8. Extend the lab with **automatic Jenkins rollback testing**, then blue-green and canary deployment strategies.

## 13. Interview explanation (5-year DevOps level)

> I built an end-to-end AWS DevOps lab using Terraform, Jenkins, Docker, SonarCloud, Trivy, ECR, and EKS. I separated reusable AWS infrastructure and add-ons from plain Kubernetes YAML. Jenkins checks out the Java source, runs Maven tests and SonarCloud analysis, builds a Docker image, scans library dependencies with Trivy, then pushes a uniquely tagged image to ECR. After a manual approval, Jenkins assumes a restricted AWS deployment role and updates the Kubernetes Deployment. I validated two healthy Pods across separate worker nodes, healthy ALB targets, and HTTP 200 from the login endpoint. I also tested a manual rollback and successful restoration to the latest image. Next, I plan to test the pipeline's automatic rollback path and add HTTPS.

---

**Last documented validation:** 2 November 2026 · **Known-good image:** `ci-22-d1be085` · **Namespace:** `production-v3`
