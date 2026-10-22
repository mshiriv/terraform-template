#!/usr/bin/env bash
#
# new-root.sh: scaffold a new AWS Terraform root that follows the repo
# conventions (file layout, backend key, provider default_tags, typed and
# validated variables, terraform-docs README, cross-tier remote state).
#
# Usage:
#   scripts/new-root.sh aws/accounts/<env>/<region>/01-foundation
#   scripts/new-root.sh aws/accounts/<env>/<region>/02-platform
#   scripts/new-root.sh aws/accounts/<env>/<region>/03-workloads/<product>
#   scripts/new-root.sh aws/accounts/<env>/<account-level-root>    # e.g. config
#
# The state bucket prefix and Repository tag are read from aws/bootstrap, so
# this works before and after scripts/init-template.sh. CI picks the new root
# up automatically (scripts/detect-changes.sh keys on backend.tf).

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

DIR="${1:?Usage: scripts/new-root.sh aws/accounts/<env>/...  (see the header of this script)}"
DIR="${DIR%/}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

[[ -e "$DIR" ]] && die "$DIR already exists."

IFS='/' read -r -a parts <<<"$DIR"
[[ "${parts[0]:-}" == "aws" && "${parts[1]:-}" == "accounts" ]] ||
  die "only aws/accounts/<env>/... roots are scaffolded (Azure/Datadog: copy an existing root)."

ENV="${parts[2]:-}"
case "$ENV" in
  management | production | staging | sandbox) ;;
  *) die "unknown environment '$ENV' (expected management, production, staging or sandbox)." ;;
esac

BUCKET_PREFIX=$(sed -n 's/^[[:space:]]*bucket[[:space:]]*=[[:space:]]*"\(.*\)-management".*/\1/p' aws/bootstrap/backend.tf | head -1)
REPOSITORY=$(sed -n 's/^[[:space:]]*Repository[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' aws/bootstrap/providers.tf | head -1)
[[ -n "$BUCKET_PREFIX" && -n "$REPOSITORY" ]] || die "could not read the state bucket prefix / Repository tag from aws/bootstrap."
BUCKET="${BUCKET_PREFIX}-${ENV}"

REGION_RE='^[a-z]{2}(-gov)?-[a-z]+-[0-9]$'
PRODUCT="shared"
DATA_TIERS=()

if [[ "${parts[3]:-}" =~ $REGION_RE ]]; then
  REGION="${parts[3]}"
  TIER_DIR="${parts[4]:-}"
  case "$TIER_DIR" in
    01-foundation)
      TIER="foundation"
      [[ ${#parts[@]} -eq 5 ]] || die "01-foundation takes no sub-directory."
      ;;
    02-platform)
      TIER="platform"
      DATA_TIERS=(01-foundation)
      [[ ${#parts[@]} -eq 5 ]] || die "02-platform takes no sub-directory."
      ;;
    03-workloads)
      TIER="workloads"
      PRODUCT="${parts[5]:-}"
      [[ -n "$PRODUCT" && ${#parts[@]} -eq 6 ]] || die "use aws/accounts/<env>/<region>/03-workloads/<product>."
      [[ "$PRODUCT" =~ ^[a-z][a-z0-9-]*$ ]] || die "product name must be lowercase kebab-case."
      DATA_TIERS=(01-foundation 02-platform)
      ;;
    *) die "tier must be 01-foundation, 02-platform or 03-workloads/<product> (got '$TIER_DIR')." ;;
  esac
  KEY="${DIR#aws/accounts/"$ENV"/}/terraform.tfstate"
else
  # Account-level root (IAM, Config, hardening...): one per account, us-east-1.
  NAME="${parts[3]:-}"
  [[ -n "$NAME" && ${#parts[@]} -eq 4 ]] || die "account-level roots live at aws/accounts/<env>/<name>."
  [[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || die "root name must be lowercase kebab-case."
  REGION="us-east-1"
  TIER="governance"
  KEY="${NAME}/terraform.tfstate"
fi

mkdir -p "$DIR"

cat >"$DIR/backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket       = "${BUCKET}"
    key          = "${KEY}"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
EOF

cat >"$DIR/providers.tf" <<EOF
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "${REGION}"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "${REPOSITORY}"
      Environment = var.environment
      Region      = "${REGION}"
      Product     = "${PRODUCT}"
      Tier        = "${TIER}"
    }
  }
}
EOF

cat >"$DIR/variables.tf" <<EOF
variable "environment" {
  description = "Environment (account short name)."
  type        = string
  default     = "${ENV}"
  nullable    = false

  validation {
    condition     = contains(["management", "production", "staging", "sandbox"], var.environment)
    error_message = "environment must be one of management, production, staging, sandbox."
  }
}
EOF

cat >"$DIR/main.tf" <<EOF
# ${DIR#aws/accounts/}
#
# TODO: one paragraph on what this root owns and why it lives in this tier
# (see the decision tree in aws/README.md).
EOF

cat >"$DIR/outputs.tf" <<EOF
# Outputs read by other roots via terraform_remote_state. Every output needs a
# description; mark secrets sensitive (check consumers first, see CLAUDE.md).
EOF

if [[ ${#DATA_TIERS[@]} -gt 0 ]]; then
  {
    echo "# Cross-tier reads: higher tiers read lower ones, never the reverse."
    for t in "${DATA_TIERS[@]}"; do
      label="${t#*-}"
      cat <<EOF

data "terraform_remote_state" "${label}" {
  backend = "s3"
  config = {
    bucket = "${BUCKET}"
    key    = "${REGION}/${t}/terraform.tfstate"
    region = "us-east-1"
  }
}
EOF
    done
  } >"$DIR/data.tf"
fi

cat >"$DIR/README.md" <<EOF
# ${DIR#aws/accounts/}

TODO: what this root manages, who owns it, anything unusual about applying it.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
EOF

echo "Scaffolded $DIR:"
for f in "$DIR"/*; do echo "  ${f##*/}"; done
cat <<EOF

Next:
  1. Write the resources in main.tf (prefer terraform-aws-modules/* where one fits).
  2. pre-commit run --files $DIR/*   # fmt, validate, tflint, docs, checkov, trivy
  3. Add a CODEOWNERS line if the root is security-sensitive.
  4. Open a PR: CI plans the new root automatically.
EOF
