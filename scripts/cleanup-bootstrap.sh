#!/bin/bash
set -e

# Configuration
# Must match the values used in bootstrap-new-account.sh
ROLE_NAME="GitHubDeployRole"
OIDC_URL="token.actions.githubusercontent.com"

echo "Cleaning up Bootstrap Resources..."

# 1. Delete IAM Role
echo "Deleting IAM Role: $ROLE_NAME..."
if aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    # Detach policies first
    echo "Detaching policies..."
    POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[*].PolicyArn' --output text)
    for policy in $POLICIES; do
        aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $policy
        echo "Detached $policy"
    done

    # Delete the role
    aws iam delete-role --role-name $ROLE_NAME
    echo "Role deleted."
else
    echo "Role $ROLE_NAME not found."
fi

# 2. Delete OIDC Provider
echo "Deleting OIDC Provider..."
# Find the ARN of the provider
PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_URL')].Arn" --output text)

if [ -n "$PROVIDER_ARN" ]; then
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $PROVIDER_ARN
    echo "OIDC Provider deleted: $PROVIDER_ARN"
else
    echo "OIDC Provider not found."
fi

echo "--------------------------------------------------"
echo "Cleanup Complete!"
echo "--------------------------------------------------"
