# EKS Cluster Project Guidelines

## Commands
- Initialize: `terraform init`
- Validate: `terraform validate`
- Format code: `terraform fmt`
- Plan changes: `terraform plan`
- Apply changes: `terraform apply`
- Infrastructure tests: `kubectl cluster-info` (verify cluster connection)
- K8s deployments: `kubectl apply -f <manifest-file>.yaml`
- Verify services: `kubectl get all -n <namespace> --selector <label>`

## Code Style
- Use absolute paths with tools that require them
- Format Terraform files using `terraform fmt` before committing
- Follow existing naming conventions (lowercase-hyphenated)
- Use consistent resource prefix (`mb-` in this project)
- Error handling: Use detailed AWS IAM policies as defined in `iam-policies/`
- Use HCL language features appropriately in Terraform
- Keep manifests well-documented with comments
- Structure K8s manifests using standard resource types
- Follow AWS and Kubernetes best practices for resource definitions