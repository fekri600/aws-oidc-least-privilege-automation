# AWS CI Least Privilege Automation

> **Automate the creation of strictly least-privilege IAM policies for GitHub Actions (using OIDC) based on real CloudTrail logs.**

[![Terraform](https://img.shields.io/badge/Terraform-1.12.2-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-CloudTrail%20%7C%20Access%20Analyzer-232F3E?logo=amazon-aws)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Table of Contents

- [Project Overview](#-project-overview)
- [The Problem](#-the-problem)
- [The Solution](#-the-solution)
- [The Least Privilege Automation Flow](#-the-least-privilege-automation-flow)
- [Architecture](#-architecture)
- [Key Components](#-key-components)
- [Prerequisites](#-prerequisites)
- [Setup & Installation](#-setup--installation)
- [Usage](#-usage)
- [Best Practices](#-best-practices)
- [Troubleshooting](#-troubleshooting)

---

## Project Overview

This project provides an **automated, self-healing approach** to managing IAM permissions for CI/CD pipelines. It eliminates the traditional trade-off between:

- **Security**: Granting overly permissive policies (`Resource: "*"`) that violate the principle of least privilege
- **Productivity**: Spending hours manually crafting precise IAM policies for Infrastructure as Code (IaC) deployments

Instead, this solution leverages **AWS CloudTrail** and **AWS IAM Access Analyzer** to automatically generate IAM policies tailored to the **exact AWS actions and resources** used by your GitHub Actions workflows.

### Target Audience

- **DevOps Engineers** managing CI/CD pipelines
- **Cloud Architects** designing secure AWS infrastructures
- **Security Engineers** enforcing least-privilege access
- **Developers** deploying infrastructure via GitHub Actions

---

## The Problem

When deploying infrastructure via GitHub Actions with OIDC authentication, teams face a critical dilemma:

### Option 1: Overly Permissive Policies (Insecure)
```json
{
"Effect": "Allow",
"Action": ["ec2:*", "s3:*", "rds:*"],
"Resource": "*"
}
```
Violates security best practices
Grants access to all resources in the account
High blast radius if credentials are compromised

### Option 2: Manual Policy Crafting (Time-Consuming)
```json
{
"Effect": "Allow",
"Action": ["ec2:CreateVpc", "ec2:DeleteVpc", ...],
"Resource": "arn:aws:ec2:us-east-1:123456789012:vpc/*"
}
```
Follows least privilege
Requires hours of trial-and-error testing
Difficult to maintain as infrastructure evolves
Easy to miss required permissions

---

## The Solution

This project introduces a **three-phase automated workflow** that:

1. **Captures** all AWS API calls made during a complete infrastructure lifecycle (deploy + destroy)
2. **Generates** a least-privilege IAM policy using AWS Access Analyzer
3. **Refines** the policy over time through continuous monitoring

### How It Works

```

Phase 1: Initial Permissive Run (Capture All Actions)
↓ Deploy + Destroy Infrastructure with broad permissions
↓ CloudTrail logs every API call

↓

Phase 2: First Policy Generation (Wildcard Resources)
↓ ci_least_priv.py parses CloudTrail logs
↓ Generates policy with wildcard ARNs (e.g., arn:aws:ec2:*)
↓ Opens Pull Request with new policy

↓

Phase 3: Second Policy Generation (Strict Resources)
↓ Run again after infrastructure is deployed
↓ Generates policy with exact resource ARNs
↓ Opens Pull Request with strict policy

```

**Result**: A strictly least-privilege IAM policy that is:
- **Automatically generated** from real usage
- **Continuously updated** as infrastructure evolves
- **Self-documenting** via Git history and PRs
- **Audit-ready** with full CloudTrail evidence

---

## The Least Privilege Automation Flow

### Phase 1: Capturing All Necessary Actions (The "Sacrifice Run")

---

#### Step 1.1: Initial Role Setup (Permissive)

**Why start with permissive policies?**

The OIDC-assumed role for GitHub Actions initially uses a **highly permissive** `permission-policy.json`. This policy must contain **two critical statements**:

**1. Static State Management (Permanent)**

This statement ensures Terraform can always access its remote state in S3. It remains in the policy **permanently**:

```json
{
"Sid": "S3StateManagement",
"Effect": "Allow",
"Action": [
"s3:GetObject",
"s3:PutObject",
"s3:DeleteObject",
"s3:ListBucket",
"s3:GetBucketAcl",
"s3:PutObjectAcl",
"s3:CreateBucket",
"s3:PutBucketPolicy"
],
"Resource": [
"arn:aws:s3:::${state_bucket_name}/*"
]
}
```

**2. Temporary Capture Statement (Removed After Phase 2)**

This wildcard statement is **temporary** and exists solely to capture all required permissions:

```json
{
"Effect": "Allow",
"Action": ["*"],
"Resource": "*"
}
```

**Why this two-statement structure?**

- **State Management**: The explicit S3 permissions ensure Terraform state operations work even after the temporary wildcard is removed
- **Complete Coverage**: The wildcard statement ensures CloudTrail captures *every* AWS action required for the full infrastructure lifecycle
- **Unknown Resources**: Some actions (e.g., `ec2:DescribeVpcs`, `s3:ListBucket`) require `Resource: "*"` by AWS design
- **Dynamic Resource IDs**: Resources created during deployment (VPC IDs, subnet IDs) cannot be known in advance
- **Destroy Actions**: Cleanup operations often require different permissions than creation

**Complete Initial Policy Example**:
```json
{
"Version": "2012-10-17",
"Statement": [
{
"Sid": "S3StateManagement",
"Effect": "Allow",
"Action": [
"s3:GetObject",
"s3:PutObject",
"s3:DeleteObject",
"s3:ListBucket",
"s3:GetBucketAcl",
"s3:PutObjectAcl",
"s3:CreateBucket",
"s3:PutBucketPolicy"
],
"Resource": [
"arn:aws:s3:::terraform-state-bucket-abc123/*"
]
},
{
"Effect": "Allow",
"Action": ["*"],
"Resource": "*"
}
]
}
```

> **Important**: The wildcard statement is **temporary** and will be replaced with least-privilege statements in Phase 2. The `S3StateManagement` statement is **permanent** and preserved through all policy updates via the `--preserve-sids S3StateManagement` flag in `ci_least_priv.py`.
---

#### Step 1.2: Infrastructure Lifecycle Run (Deploy + Destroy)

Execute the **full deployment and cleanup cycle** by running the `deploy-demo-infra.yml` pipeline:

**Deploy Phase**:
```bash
# Triggered automatically on push to main, or manually via workflow_dispatch
terraform init
terraform apply -auto-approve
```

**Destroy Phase** (Critical):
```bash
# Manually triggered via workflow_dispatch with action='destroy'
terraform destroy -auto-approve
```

**Why destroy immediately after deploying?**

Destroying the infrastructure ensures CloudTrail captures **all necessary permissions**, including:

- **Creation permissions**: `ec2:CreateVpc`, `s3:CreateBucket`, etc.
- **Destroy permissions**: `ec2:DeleteVpc`, `s3:DeleteBucket`, etc.
- **Dependency management**: `ec2:DetachInternetGateway` before `ec2:DeleteVpc`
- **Read permissions**: `ec2:DescribeVpcs`, `s3:GetBucketLocation`

**Without the destroy run**, the generated policy would be incomplete and fail during cleanup operations.

**CloudTrail Logging**:
- All API calls are logged to an S3 bucket
- CloudTrail captures: action, resource, timestamp, principal, request parameters
- Logs are retained for 90 days (configurable)

---

### Phase 2: Automated Least Privilege Policy Generation

#### Step 2.1: First Policy Generation Run (Wildcard Resources)

After completing the deploy + destroy cycle in Phase 1, run the **`least-priv-ci.yml`** workflow for the first time.

**What happens**:

1. **CloudTrail Analysis**: The `ci_least_priv.py` script queries CloudTrail logs from the past 24 hours (configurable)
2. **IAM Access Analyzer**: Invokes `StartPolicyGeneration` with CloudTrail data
3. **Policy Generation**: Access Analyzer correlates API calls with IAM actions and generates a minimal policy
4. **Wildcard Resources**: The policy contains resource ARNs with wildcards (e.g., `arn:aws:ec2:*:*:vpc/*`)

**Why wildcards in the first pass?**

- **Dynamic Infrastructure**: Resource IDs (VPC IDs, subnet IDs, etc.) are unknown until resources are created
- **Continuous Delivery**: The policy must work for future deployments where resource IDs will differ
- **Flexibility**: Wildcards allow the policy to cover all resources of a specific type in a region

**Pull Request**:
- The script opens a PR with the updated `permission-policy.json`
- PR includes: policy diff, lookback window, CloudTrail evidence
- **Review & Merge**: Inspect the policy, approve, and merge

---

#### Step 2.2: Second Policy Generation Run (Strict Resources)

After the infrastructure is deployed using the wildcard policy (or if infrastructure is already running), run the **`least-priv-ci.yml`** workflow **again**.

**What happens**:

1. **Active Infrastructure**: CloudTrail logs now contain API calls against **specific resource IDs** (e.g., `vpc-0a1b2c3d`)
2. **Strict Policy Generation**: `ci_least_priv.py` processes the new logs
3. **Exact ARNs**: The policy is updated with **precise resource ARNs** instead of wildcards

**Why run twice?**

- **First Run**: Captures the *types* of actions and resources needed (wildcards)
- **Second Run**: Captures the *exact* resources being managed (specific ARNs)
- **Result**: The strictest possible policy while still allowing operations on deployed infrastructure

**Pull Request**:
- Second PR with the strict policy
- **Review & Merge**: Approve and merge
- The OIDC role now uses the **strictest least-privilege policy** possible

---

## Architecture

```

GitHub Actions (OIDC)

deploy-demo-infra least-priv-ci.yml

• terraform apply • Run ci_least_priv.py
• terraform destroy • Generate policy
• Open PR

OIDC Assume Role OIDC Assume Role

AWS Account

IAM OIDC Role CloudTrail Access
(Pipeline) Analyzer
• Logs all
• permission- API calls • Generates
policy.json • S3 bucket policy

Manages Infrastructure

Infrastructure (VPC, S3, Route53, etc.)

```

---

## Key Components

### 1. `ci_least_priv.py`

**Location**: `services/query-ct-lack/ci_least_priv.py`

**Purpose**: The core automation script that:
- Queries AWS CloudTrail logs via IAM Access Analyzer
- Correlates API calls with IAM actions and resources
- Generates a minimal, least-privilege IAM policy in JSON format
- Handles wildcard resources intelligently (preserves legitimate `*` resources)
- Filters noise actions (e.g., `sts:GetCallerIdentity`, internal Access Analyzer calls)
- Merges new policy with existing critical statements (e.g., S3 state management)

**Usage**:
```bash
python services/query-ct-lack/ci_least_priv.py \
--principal-arn "arn:aws:iam::123456789012:role/github-oidc-role" \
--trail-arn "arn:aws:cloudtrail:us-east-1:123456789012:trail/main-trail" \
--access-role-arn "arn:aws:iam::123456789012:role/access-analyzer-role" \
--policy-path "bootstrap/modules/oidc/policies/permission-policy.json" \
--lookback-hours 24 \
--keep-star-resources
```

---

### 2. `least-priv-ci.yml`

**Location**: `.github/workflows/least-priv-ci.yml`

**Purpose**: The **self-healing CI/CD pipeline** that:
- Runs on-demand via `workflow_dispatch`
- Assumes the GitHub OIDC role (the role being analyzed)
- Executes `ci_least_priv.py` with CloudTrail data
- Opens a Pull Request with the updated policy
- Enables continuous policy refinement as infrastructure evolves

**Trigger**:
```bash
# Manual trigger via GitHub Actions UI or API
gh workflow run least-priv-ci.yml -f hours=72
```

---

### 3. `deploy-demo-infra.yml`

**Location**: `.github/workflows/deploy-demo-infra.yml`

**Purpose**: Deploys and destroys the demo infrastructure, triggering CloudTrail logging for policy generation.

**Usage**:
```bash
# Deploy infrastructure
gh workflow run deploy-demo-infra.yml -f action=deploy

# Destroy infrastructure (requires confirmation)
gh workflow run deploy-demo-infra.yml -f action=destroy -f confirm_destroy=DESTROY
```

---

## Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads) >= 1.12.2
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [Python](https://www.python.org/downloads/) >= 3.11
- [GitHub CLI](https://cli.github.com/) (optional, for automation)

### AWS Requirements
- AWS Account with administrative access (for bootstrap)
- CloudTrail enabled (or use the provided bootstrap module)
- IAM permissions to create OIDC Identity Providers, IAM Roles, and CloudTrail trails

### GitHub Requirements
- GitHub repository with Actions enabled
- GitHub personal access token (PAT) with `repo` and `workflow` scopes

---

## Setup & Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/aws-ci-least-privilege-automation.git
cd aws-ci-least-privilege-automation
```

### Step 2: Bootstrap AWS Infrastructure

```bash
cd bootstrap
terraform init
terraform apply

# Export outputs as GitHub Secrets
make bootstrap-secrets
```

### Step 3: Configure GitHub Secrets

Set the following secrets in your GitHub repository:

| Secret Name | Description |
|----------------------------------|------------------------------------------|
| `AWS_OIDC_ROLE_ARN` | IAM role for GitHub Actions (pipeline) |
| `AWS_CLOUDTRAIL_ARN` | CloudTrail trail ARN |
| `AWS_ACCESS_ANALYZER_ROLE_ARN` | Access Analyzer read role ARN |
| `LEAS_PREV_PR` | GitHub PAT for creating PRs |

---

## Usage

### Phase 1: Initial Deployment + Destruction

```bash
# Deploy infrastructure
gh workflow run deploy-demo-infra.yml -f action=deploy

# Destroy infrastructure
gh workflow run deploy-demo-infra.yml -f action=destroy -f confirm_destroy=DESTROY
```

### Phase 2: Generate Least Privilege Policy

#### First Pass (Wildcard Resources)

```bash
gh workflow run least-priv-ci.yml -f hours=24
```

Review and merge the Pull Request, then update the IAM role:

```bash
cd bootstrap && terraform apply -auto-approve
```

#### Second Pass (Strict Resources)

```bash
# Deploy infrastructure with new policy
gh workflow run deploy-demo-infra.yml -f action=deploy

# Generate strict policy
gh workflow run least-priv-ci.yml -f hours=72
```

Review and merge the second Pull Request.

---

## Best Practices

1. **Use Longer Lookback Windows for Second Pass** (72-168 hours vs 24 hours)
2. **Always Run Deploy + Destroy for Phase 1** to capture cleanup permissions
3. **Review PRs Carefully** to ensure critical permissions are not removed
4. **Use `--keep-star-resources` Flag** for actions that require `Resource: "*"`
5. **Test Policy Changes in Non-Production** before promoting to production
6. **Run Weekly** to keep policies updated as infrastructure evolves

---

## Troubleshooting

### Issue: `AUTHORIZATION_ERROR` from Access Analyzer

**Solution**: Ensure the Access Analyzer role has permissions to read CloudTrail logs:

```json
{
"Effect": "Allow",
"Action": ["s3:GetObject", "s3:ListBucket", "cloudtrail:GetTrail"],
"Resource": ["arn:aws:s3:::cloudtrail-bucket/*", "*"]
}
```

### Issue: Policy Contains Too Many `Resource: "*"`

**Solution**:
1. Run Second Pass after deploying infrastructure
2. Use `--lookback-hours 168` for more comprehensive logs
3. Some actions legitimately require `*` (e.g., `ec2:DescribeAccountAttributes`)

### Issue: Terraform State Lock Error

**Solution**:
```bash
terraform force-unlock <LOCK_ID>
```

---

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

---

## License

This project is licensed under the MIT License.

---

## Acknowledgments

- **AWS IAM Access Analyzer Team** for the policy generation API
- **CloudTrail Team** for comprehensive API logging
- **Terraform Community** for IaC best practices

---

**Built with for DevOps Engineers**
