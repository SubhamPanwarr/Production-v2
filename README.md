# Production-v2

Clean production-style AWS/EKS lab with three separate layers:

1. Terraform infrastructure (`terraform/environments/prod/infra`)
2. Terraform EKS platform add-ons (`terraform/environments/prod/addons`)
3. Native Kubernetes YAML workloads (`kubernetes/prod`)

The original `Production` repository is intentionally kept unchanged for comparison.

See `SETUP.md` for the build order and commands.
