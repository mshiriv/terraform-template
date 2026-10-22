#!/usr/bin/env bash
#
# bootstrap.sh: one-time AWS landing-zone bootstrap, run by a human from the
# management account. Idempotent: safe to re-run; every step converges.
#
# Prerequisites (see SETUP.md):
#   - scripts/init-template.sh has been run (no template placeholders left)
#   - aws/organization/terraform.tfvars filled in (real account emails)
#   - admin credentials for the MANAGEMENT account in the environment
#     (e.g. `export AWS_PROFILE=management-admin`)
#   - terraform >= 1.14, aws CLI v2, jq
#
# Steps:
#   0. Create + harden the management account's state bucket (the only
#      resource not managed by Terraform: every other root's state lives in
#      a bucket Terraform creates, but something has to hold the first state)
#   1. Apply aws/organization          (organization, OUs, accounts, SCPs)
#   2. Apply aws/bootstrap             (member-account state buckets)
#   3. Apply aws/accounts/management/github-oidc
#   4. Apply aws/accounts/<member>/github-oidc in each member account, via the
#      OrganizationAccountAccessRole
# Then it prints the role ARNs to store as GitHub secrets.
#
# Optional: export EXPECTED_MANAGEMENT_ACCOUNT_ID=123456789012 to refuse to
# run against any other account.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MEMBER_ACCOUNTS=(production staging sandbox)

backend_value() { # backend_value <root> <key>: read a literal from backend.tf
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"\(.*\)\".*/\1/p" "$REPO_ROOT/$1/backend.tf" | head -1
}

MGMT_BUCKET="$(backend_value aws/bootstrap bucket)"
STATE_REGION="$(backend_value aws/bootstrap region)"

echo "============================================"
echo "  AWS landing zone bootstrap"
echo "============================================"
echo ""

# -------------------------------------------------------------------
# Pre-flight checks
# -------------------------------------------------------------------
for cmd in aws terraform jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is not installed."
    exit 1
  fi
done

if [[ ! "$MGMT_BUCKET" =~ ^[a-z0-9][a-z0-9.-]+$ ]] || grep -rqs 'YOUR_GITHUB_ORG' "$REPO_ROOT/aws"; then
  echo "ERROR: template placeholders are still present (state bucket '$MGMT_BUCKET')."
  echo "Run scripts/init-template.sh first (see SETUP.md)."
  exit 1
fi

echo "Verifying AWS credentials..."
CALLER_IDENTITY=$(aws sts get-caller-identity --output json) || {
  echo "ERROR: AWS credentials not configured for the management account."
  exit 1
}
ACCOUNT_ID=$(jq -r '.Account' <<<"$CALLER_IDENTITY")
echo "Authenticated as: $(jq -r '.Arn' <<<"$CALLER_IDENTITY")"
echo "Account: $ACCOUNT_ID"

if [[ -n "${EXPECTED_MANAGEMENT_ACCOUNT_ID:-}" && "$ACCOUNT_ID" != "$EXPECTED_MANAGEMENT_ACCOUNT_ID" ]]; then
  echo "ERROR: expected management account $EXPECTED_MANAGEMENT_ACCOUNT_ID, got $ACCOUNT_ID."
  exit 1
fi
echo ""

# apply_root <dir> [extra terraform args...]: init, plan, confirm, apply.
apply_root() {
  local dir="$1"
  shift
  echo "--- terraform: $dir ---"
  terraform -chdir="$REPO_ROOT/$dir" init -input=false
  terraform -chdir="$REPO_ROOT/$dir" plan -input=false -out=tfplan "$@"

  if terraform -chdir="$REPO_ROOT/$dir" show -json tfplan |
    jq -e '[.resource_changes[]? | select(.change.actions != ["no-op"] and .change.actions != ["read"])] | length == 0' &>/dev/null; then
    echo "No changes. Skipping apply."
  else
    echo ""
    read -rp "Review the plan above. Apply $dir? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
      rm -f "$REPO_ROOT/$dir/tfplan"
      echo "Aborted."
      exit 1
    fi
    terraform -chdir="$REPO_ROOT/$dir" apply -input=false tfplan
  fi
  rm -f "$REPO_ROOT/$dir/tfplan"
  echo ""
}

# -------------------------------------------------------------------
# Step 0: create and harden the management state bucket
#
# Creates the bucket only if missing, then ALWAYS (re)applies hardening, so a
# bucket created by hand converges too.
# -------------------------------------------------------------------
echo "--- Step 0: management state bucket ($MGMT_BUCKET, $STATE_REGION) ---"

if aws s3api head-bucket --bucket "$MGMT_BUCKET" 2>/dev/null; then
  echo "Bucket $MGMT_BUCKET already exists."
else
  echo "Creating bucket $MGMT_BUCKET..."
  if [[ "$STATE_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$MGMT_BUCKET" --region "$STATE_REGION"
  else
    aws s3api create-bucket --bucket "$MGMT_BUCKET" --region "$STATE_REGION" \
      --create-bucket-configuration "LocationConstraint=$STATE_REGION"
  fi
fi

aws s3api put-bucket-versioning --bucket "$MGMT_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$MGMT_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms" },
      "BucketKeyEnabled": true
    }]
  }'

aws s3api put-public-access-block --bucket "$MGMT_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-ownership-controls --bucket "$MGMT_BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

aws s3api put-bucket-policy --bucket "$MGMT_BUCKET" --policy "$(jq -nc --arg b "$MGMT_BUCKET" '{
  Version: "2012-10-17",
  Statement: [{
    Sid: "DenyInsecureTransport",
    Effect: "Deny",
    Principal: "*",
    Action: "s3:*",
    Resource: ["arn:aws:s3:::\($b)", "arn:aws:s3:::\($b)/*"],
    Condition: { Bool: { "aws:SecureTransport": "false" } }
  }]
}')"

aws s3api put-bucket-lifecycle-configuration --bucket "$MGMT_BUCKET" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-noncurrent-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": { "NoncurrentDays": 90 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }]
  }'

echo "Management state bucket ready."
echo ""

# -------------------------------------------------------------------
# Step 1: organization, OUs, member accounts, SCPs
# -------------------------------------------------------------------
echo "--- Step 1: aws/organization ---"
apply_root aws/organization

ACCOUNT_IDS_JSON=$(terraform -chdir="$REPO_ROOT/aws/organization" output -json account_ids)
echo "Member accounts:"
jq -r 'to_entries[] | "  \(.key): \(.value)"' <<<"$ACCOUNT_IDS_JSON"
echo ""

# -------------------------------------------------------------------
# Step 2: member-account state buckets
# -------------------------------------------------------------------
echo "--- Step 2: aws/bootstrap ---"
apply_root aws/bootstrap -var="account_ids=$ACCOUNT_IDS_JSON"

# -------------------------------------------------------------------
# Step 3: CI role in the management account
# -------------------------------------------------------------------
echo "--- Step 3: aws/accounts/management/github-oidc ---"
apply_root aws/accounts/management/github-oidc
MGMT_ROLE_ARN=$(terraform -chdir="$REPO_ROOT/aws/accounts/management/github-oidc" output -raw github_actions_role_arn)

# -------------------------------------------------------------------
# Step 4: CI role in each member account (assumed via the role AWS
# Organizations created in every new account)
# -------------------------------------------------------------------
SECRETS_SUMMARY="  AWS_ROLE_MANAGEMENT = $MGMT_ROLE_ARN"
for env in "${MEMBER_ACCOUNTS[@]}"; do
  member_id=$(jq -r --arg e "$env" '.[$e] // empty' <<<"$ACCOUNT_IDS_JSON")
  if [[ -z "$member_id" ]]; then
    echo "Skipping $env: not in aws/organization account_ids."
    continue
  fi
  echo "--- Step 4: aws/accounts/$env/github-oidc (account $member_id) ---"
  creds=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${member_id}:role/OrganizationAccountAccessRole" \
    --role-session-name "bootstrap-github-oidc" --output json)
  # Subshell: the member credentials (and the member-account backend they
  # unlock) must not leak into later steps.
  role_arn=$(
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' <<<"$creds")
    AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' <<<"$creds")
    AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' <<<"$creds")
    unset AWS_PROFILE
    apply_root "aws/accounts/$env/github-oidc" >&2
    terraform -chdir="$REPO_ROOT/aws/accounts/$env/github-oidc" output -raw github_actions_role_arn
  )
  SECRETS_SUMMARY+=$'\n'"  AWS_ROLE_$(tr '[:lower:]' '[:upper:]' <<<"$env") = $role_arn"
done

echo ""
echo "============================================"
echo "  Bootstrap complete"
echo "============================================"
echo ""
echo "Store these as GitHub repository secrets (SETUP.md, step 6):"
echo "$SECRETS_SUMMARY"
echo ""
echo "Then set the repository variable CI_AWS_ENABLED=true and open a PR."
