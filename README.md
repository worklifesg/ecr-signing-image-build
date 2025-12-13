# ECR Signing Pipeline

This project implements an enterprise-grade secure container supply chain using AWS ECR, KMS, and GitHub Actions, featuring automated image signing, SBOM attestations, multi-region replication, and comprehensive security guardrails.

## Setup

(See "Project Structure & File Descriptions" above for detailed setup per repository)

## GitHub Secrets & Variables Configuration

To run the pipelines successfully, configure the following in your GitHub Repository settings:

### Secrets (Settings > Secrets and variables > Actions > New repository secret)
| Secret Name | Description |
|-------------|-------------|
| `AWS_ROLE_ARN` | The ARN of the role created by Terraform for the **Build** pipeline (Output: `role_arn`). | 
| `KMS_KEY_ARN` | The ARN of the KMS key created by Terraform (Output: `kms_key_arn`). |
| `AWS_TERRAFORM_ROLE_ARN` | An AWS Role ARN with Admin permissions to **deploy** the infrastructure (used by `deploy-infra.yml`). |
| `TF_VAR_ADMIN_ROLE_NAME` | The sensitive name of your Admin role (e.g., `aws-reserved/sso...`). |
| `TF_STATE_BUCKET` | Name of the S3 bucket to store Terraform state. |
| `TF_STATE_DYNAMODB_TABLE` | Name of the DynamoDB table for state locking. |

### Variables (Settings > Secrets and variables > Actions > New repository variable)
| Variable Name | Value Example | Description |
|---------------|---------------|-------------|
| `APP_REPO_NAME` | `my-org/my-repo` | Your GitHub repository identifier. |
| `ECR_IMAGE_REPO` | `my-app-images` | Name of the image repository. |
| `ECR_SIG_REPO` | `my-app-signatures` | Name of the signature repository. |

## Architecture
- **Images**: Stored in `my-app-images`
- **Signatures**: Stored in `my-app-signatures` (via `COSIGN_REPOSITORY` env var)
- **Signing**: Performed via OIDC auth using AWS KMS Asymmetric keys.
- **Replication**: Images and signatures are automatically replicated to a secondary region (default: `ca-central-1`) for disaster recovery.
- **Access Control**: Strict ECR Repository Policies ensure only the GitHub Actions role and account admins can push/pull images.
- **Infrastructure State**: Managed via Terraform with S3 backend and DynamoDB locking. The pipeline automatically creates these resources if they don't exist.
- **Tagging Strategy**: Implements a hybrid strategy:
    - **Releases**: Uses semantic versioning (e.g., `v1.0.0`) when a git tag is pushed.
    - **CI Builds**: Uses chronological tags (e.g., `20251126-a1b2c3d`) for commits to `main`.

## Project Structure & File Descriptions

The project is split into two repositories to simulate a real-world separation of concerns:

### 1. Infrastructure Repository (`infrastructure-repo/`)
Contains the Terraform code and deployment pipelines managed by the Platform Team.

*   **`terraform/`**:
    *   **`main.tf`**: Entry point for Terraform.
    *   **`variables.tf`**: Defines input variables. **Important**: `github_repo` must point to the **Application Repository**.
    *   **`ecr.tf`**: Creates ECR repos, replication, and policies.
    *   **`kms.tf`**: Creates the KMS Asymmetric key for signing.
    *   **`iam.tf`**: Sets up OIDC trust for the **Application Repository**.
*   **`.github/workflows/deploy-infra.yml`**: Automates infrastructure deployment.

### 2. Application Repository (`app-repo/`)
Contains the application source code and build pipelines managed by the Application Team.

*   **`Dockerfile`**: Defines the Trino-based container image.
*   **`etc/`**: Configuration files for the application.
*   **`scripts/`**: Helper scripts (e.g., `verify-signature.sh`).
*   **`.github/workflows/build-and-sign.yml`**: The main CI/CD pipeline that builds, scans, signs, and pushes the image.

## Setup

### 1. Infrastructure Setup (Platform Team)
1.  Navigate to `infrastructure-repo/terraform`.
2.  Run Terraform to provision resources:
    ```bash
    terraform init
    terraform apply
    ```
3.  Note the outputs: `role_arn`, `kms_key_arn`, `image_repo_url`, `signature_repo_url`.

### 2. GitHub Configuration

#### Infrastructure Repository (`infrastructure-repo`)
Configure these secrets to allow the `deploy-infra` workflow to run:
*   `AWS_TERRAFORM_ROLE_ARN`: Admin role for deployment.
*   `TF_STATE_BUCKET`: S3 bucket for state.
*   `TF_STATE_DYNAMODB_TABLE`: DynamoDB table for locking.
*   `TF_VAR_ADMIN_ROLE_NAME`: Admin role name.
*   `APP_REPO_NAME`: Variable pointing to the **Application Repository** (e.g., `my-org/app-repo`).

#### Application Repository (`app-repo`)
Configure these secrets to allow the `build-and-sign` workflow to push and sign images:
*   `AWS_ROLE_ARN`: The `role_arn` output from Terraform.
*   `KMS_KEY_ARN`: The `kms_key_arn` output from Terraform.
*   `ECR_IMAGE_REPO`: Variable (e.g., `my-app-images`).
*   `ECR_SIG_REPO`: Variable (e.g., `my-app-signatures`).

## Security Guardrails
The pipeline integrates the following security tools to ensure supply chain security:

1. **Gitleaks**: Scans source code for hardcoded secrets and credentials.
2. **Hadolint**: Lints the `Dockerfile` for best practices and syntax errors.
3. **Checkov**: Scans Terraform infrastructure code for security misconfigurations.
4. **Dockle**: Checks the built container image against CIS Docker Benchmarks (e.g., non-root user).
5. **Trivy**: Scans the container image for OS and library vulnerabilities (CVEs).

If any of these checks fail (Critical/High severity), the pipeline stops, and the image is **not** pushed or signed.

## Cost Optimization
This project is designed to be cost-effective for both active use and "Demo & Park" scenarios:
- **DynamoDB**: Configured with `PAY_PER_REQUEST` billing, ensuring $0.00 monthly cost when idle.
- **ECR Lifecycle**: Automatically expires images older than the last 30 to minimize storage costs.
- **KMS**: The only fixed cost is the KMS key (~$1.00/month).

## Supply Chain Attestations
Beyond simple signing, this pipeline implements Enterprise-grade supply chain security by attaching signed attestations to the image in ECR:

*   **SBOM (Software Bill of Materials)**: Generated by `syft`, listing all packages in the image.
*   **Vulnerability Report**: The `trivy` scan results (SARIF format).

These attestations are cryptographically linked to the image digest. You can verify them using Cosign:
```bash
# Verify SBOM
cosign verify-attestation --key <kms-key-arn> --type spdxjson <image-uri>

# Verify Vulnerability Scan
cosign verify-attestation --key <kms-key-arn> --type sarif <image-uri>
```
