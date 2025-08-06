#!/bin/bash

# Set HCP Vault cluster details
export VAULT_ADDR="<YOUR_VAULT_ADDR>"
export VAULT_NAMESPACE="admin"
export VAULT_TOKEN="<YOUR_VAULT_TOKEN>"

echo "Testing Vault status..."
if vault status; then
    echo "Vault connection successful!"
else
    echo "Vault connection failed!"
    exit 1
fi

echo ""
echo "Testing authentication..."
if vault auth list; then
    echo "Authentication successful!"
else
    echo "Authentication failed!"
    exit 1
fi

echo ""
echo "Checking existing auth methods..."
vault auth list

echo ""
echo "Checking existing policies..."
vault policy list

echo ""
echo "Checking secrets engines..."
vault secrets list

# GitHub repository details
GITHUB_ORG="sivajayaraman"
GITHUB_REPO="test-tf-ws-hvd-integ"
ROLE_NAME="github-actions-role"
SECRET_PATH="github-actions"

echo "Setting up OIDC integration for GitHub Actions..."
echo "GitHub Repository: ${GITHUB_ORG}/${GITHUB_REPO}"
echo "Role Name: ${ROLE_NAME}"
echo "Secret Path: secret/data/${SECRET_PATH}"

# Enable KV secrets engine
echo "Enabling KV secrets engine..."
if vault secrets list | grep -q "secret/"; then
    echo "KV secrets engine already enabled at secret/"
else
    echo "Enabling KV v2 secrets engine at secret/"
    vault secrets enable -path=secret kv-v2
fi

# Enable JWT auth method
echo "Enabling JWT auth method..."
if vault auth list | grep -q "jwt/"; then
    echo "JWT auth method already enabled"
else
    echo "Enabling JWT auth method"
    vault auth enable jwt
fi

# Configure JWT auth method with GitHub OIDC
echo "Configuring JWT auth method..."
vault write auth/jwt/config \
  bound_issuer="https://token.actions.githubusercontent.com" \
  oidc_discovery_url="https://token.actions.githubusercontent.com"

# Create a GitHub Actions policy on the secrets path
echo "Creating Vault policy..."
vault policy write github-actions-policy - <<EOF
path "secret/data/github-actions/*" {
  capabilities = [ "read" ]
}

path "secret/metadata/github-actions/*" {
  capabilities = [ "list" ]
}

path "secret/data/ci/*" {
  capabilities = [ "read" ]
}

path "secret/metadata/ci/*" {
  capabilities = [ "list" ]
}

path "aws/creds/vault-demo-assumed-role" {
  capabilities = [ "read" ]
}

path "aws/roles/*" {
  capabilities = [ "list" ]
}
EOF

# Create JWT role with appropriate policy
echo "Creating JWT role..."
vault write auth/jwt/role/${ROLE_NAME} -<<EOF
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_audiences": ["https://github.com/${GITHUB_ORG}"],
  "bound_claims": {
    "repository": "${GITHUB_ORG}/${GITHUB_REPO}"
  },
  "bound_subjects": [
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
  ],
  "policies": ["github-actions-policy"],
  "ttl": "15m"
}
EOF

# Create test secrets
echo "Creating test secrets..."
vault kv put secret/${SECRET_PATH}/ci npmToken="npm_test_token_12345" apiKey="api_test_key_67890" dbPassword="db_test_password_xyz"

vault kv put secret/ci/terraform tfToken="terraform_cloud_token_123" awsAccessKey="aws_access_key_456" awsSecretKey="aws_secret_key_789"
