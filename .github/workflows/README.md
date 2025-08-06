# GHA OIDC Integration with HCP Vault

## Overview
This walks through the setup of OIDC integration between GHA and HCP Vault.

## Architecture
```
GitHub Actions (OIDC Token) -> Vault JWT Auth -> Vault Token -> Access Secrets & AWS Creds
```

---

## Step-by-Step Implementation

### 1: HCP Vault Configuration (`vault-oidc-setup.sh`)

#### Environment Setup
```bash
export VAULT_ADDR="*****"
export VAULT_NAMESPACE="admin"
export VAULT_TOKEN="******"
```

#### Authentication Method Setup
- **Enabled JWT auth method** for OIDC integration
- **Configured GitHub OIDC provider**:
  - `bound_issuer`: `https://token.actions.githubusercontent.com`
  - `oidc_discovery_url`: `https://token.actions.githubusercontent.com`

#### Policy Creation
Created `github-actions-policy` with permissions for:
```hcl
# Static KV secrets
path "secret/data/github-actions/*" { capabilities = ["read"] }
path "secret/data/ci/*" { capabilities = ["read"] }

# Dynamic AWS credentials  
path "aws/creds/vault-demo-assumed-role" { capabilities = ["read"] }
```

#### JWT Role Configuration
Created `github-actions-role` with:
- **Repository binding**: `sivajayaraman/test-tf-ws-hvd-integ`
- **Audience binding**: `https://github.com/sivajayaraman`
- **Subject binding**: `repo:sivajayaraman/test-tf-ws-hvd-integ:*`
- **Token TTL**: 15 minutes
- **Policies**: `github-actions-policy`

#### Test Data Creation
- **Static secrets** in `secret/github-actions/ci`: npmToken, apiKey, dbPassword
- **Static secrets** in `secret/ci/terraform`: tfToken, awsAccessKey, awsSecretKey
- For **Dynamic secrets** Follow these [steps](https://github.com/hashicorp/hc-sec-demos/blob/main/demos/vault/aws_secrets_engine/README.md)

### 2: GitHub Repository Configuration

#### 2.1 Repository Secrets
- Go to your repository.
- Click Settings -> Search Secrets and variables -> Select Actions
- We will have two tabs: Secrets & Variables
- Click “Secrets” -> “New repository secret”
- Add these values:
  - `VAULT_URL`: HCP Vault cluster URL
  - `VAULT_NAMESPACE`: `admin`

#### 2.2 Workflow Permissions
Configured required permissions in workflows:
```yaml
permissions:
  id-token: write
  contents: read
```

### 3: GitHub Actions Workflows

#### 3.1 Main Workflow (`test-vault-oidc.yml`)

**Workflow steps:**
1. **Static Secret Retrieval**:
   ```yaml
   secrets: |
     secret/data/github-actions/ci npmToken | NPM_TOKEN ;
     secret/data/ci/terraform tfToken | TF_TOKEN ;
   ```

#### 3.2 AWS Workflow (`vault-aws-workflow.yml`)
1. **Dynamic AWS Credential Retrieval**:
   ```yaml
   secrets: |
     aws/creds/vault-demo-assumed-role access_key | AWS_ACCESS_KEY_ID ;
     aws/creds/vault-demo-assumed-role secret_key | AWS_SECRET_ACCESS_KEY ;
     aws/creds/vault-demo-assumed-role security_token | AWS_SESSION_TOKEN
   ```
2. **AWS API Testing**:
   - `aws ec2 describe-regions --region us-east-1`
   - `aws sts get-caller-identity`

**Additional cases:**
- Extended AWS API validation
- Cross-region API calls
- STS caller identity checks
- Table formatted AWS responses

For GHA Setup Guide -> Followed this [doc](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-hashicorp-vault#updating-your-github-actions-workflow)
