#!/bin/bash
set -e

# Configuration
NEW_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
GITHUB_ORG="worklifesg" # Replace with your actual Org/User
REPO_NAME="ecr-signing-image-build" # Replace if different
ROLE_NAME="GitHubDeployRole"
REGION="us-east-1"

echo "Bootstrapping Account: $NEW_ACCOUNT_ID in $REGION"

# 1. Create OIDC Provider
echo "Creating OIDC Provider..."
if ! aws iam list-open-id-connect-providers | grep -q "token.actions.githubusercontent.com"; then
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "OIDC Provider created."
else
    echo "OIDC Provider already exists."
fi

# 2. Create Trust Policy
cat > trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${NEW_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/*"
                }
            }
        }
    ]
}
EOF

# 3. Create Role
echo "Creating IAM Role: $ROLE_NAME..."
if ! aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json
    echo "Role created."
else
    echo "Role already exists. Updating trust policy..."
    aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://trust-policy.json
fi

# 4. Attach Admin Policy (For Terraform to create resources)
echo "Attaching AdministratorAccess..."
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Cleanup
rm trust-policy.json

echo "--------------------------------------------------"
echo "Bootstrap Complete!"
echo "Update your GitHub Repository Secret 'AWS_TERRAFORM_ROLE_ARN' with:"
echo "arn:aws:iam::${NEW_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "--------------------------------------------------"
