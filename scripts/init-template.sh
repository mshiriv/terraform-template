#!/usr/bin/env bash
#
# init-template.sh: turn a fresh copy of the template into YOUR repo.
#
# Replaces the template placeholders in every tracked file and renames the
# region directories. Run it once, right after creating your repo from the
# template, review `git diff`, and commit on a branch.
#
# Usage:
#   scripts/init-template.sh --prefix <prefix> --github-repo <owner/name> [options]
#
# Required:
#   --prefix <prefix>         Short lowercase org prefix (a-z, 0-9; 2-15 chars).
#                             Used in globally-unique names: S3 state buckets
#                             (<prefix>-tfstate-<env>), application buckets,
#                             the Azure state storage account, account names.
#   --github-repo <owner/name>
#                             This repository. Used in the OIDC trust policies,
#                             the Repository tag, and github/repo-management.
#
# Options:
#   --region <aws-region>     Primary AWS workload region (default: eu-west-1).
#   --azure-location <loc>    Primary Azure location (default: westeurope).
#   --codeowners <owner>      CODEOWNERS owner for every path (default:
#                             @<github owner>/platform-team). Use @<username>
#                             for a personal repository.
#   --dry-run                 Show what would change; touch nothing.
#   -h, --help                Show this help.
#
# Placeholders replaced (keep this list in sync with the template):
#   YOUR_GITHUB_ORG/YOUR_GITHUB_REPO   -> --github-repo
#   @YOUR_GITHUB_ORG/platform-team     -> --codeowners
#   YOUR_GITHUB_ORG, YOUR_GITHUB_REPO  -> owner / name parts of --github-repo
#   stchangemetfstate                  -> st<prefix>tfstate (Azure storage account)
#   CHANGEME                           -> --prefix
#   eu-west-1                          -> --region (also renames the directories)
#   westeurope                         -> --azure-location (also renames the directories)
#
# Placeholders are deliberately invalid as real names (upper case is illegal in
# S3 bucket names, underscores in GitHub owners) so an un-initialized copy can
# never write state to, or trust, someone else's bucket or repository.

set -euo pipefail

# Print the header comment block (everything after the shebang up to the
# first non-comment line).
usage() { awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"; }

PREFIX=""
GITHUB_REPO=""
REGION="eu-west-1"
AZURE_LOCATION="westeurope"
CODEOWNERS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    --github-repo) GITHUB_REPO="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --azure-location) AZURE_LOCATION="${2:-}"; shift 2 ;;
    --codeowners) CODEOWNERS="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

[[ "$PREFIX" =~ ^[a-z][a-z0-9]{1,14}$ ]] ||
  die "--prefix must be 2-15 chars, lowercase letters and digits, starting with a letter (got '$PREFIX')."
[[ "$GITHUB_REPO" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9._-]+$ ]] ||
  die "--github-repo must be owner/name (got '$GITHUB_REPO')."
[[ "$REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]$ ]] ||
  die "--region must look like an AWS region, e.g. us-west-2 (got '$REGION')."
[[ "$AZURE_LOCATION" =~ ^[a-z0-9]+$ ]] ||
  die "--azure-location must be an Azure location name, e.g. eastus (got '$AZURE_LOCATION')."

GITHUB_OWNER="${GITHUB_REPO%%/*}"
GITHUB_NAME="${GITHUB_REPO#*/}"
CODEOWNERS="${CODEOWNERS:-@${GITHUB_OWNER}/platform-team}"
[[ "$CODEOWNERS" == @* ]] || die "--codeowners must start with @ (got '$CODEOWNERS')."

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this inside your git clone."
cd "$REPO_ROOT"

SELF="scripts/init-template.sh"

# Files to rewrite: everything tracked, except this script and the vendored
# skill (kept byte-identical to upstream).
files=()
while IFS= read -r -d '' f; do
  case "$f" in
    "$SELF" | .claude/skills/terraform-skill/*) continue ;;
  esac
  [[ -f "$f" ]] && files+=("$f")
done < <(git ls-files -z)

# Order matters: longer, more specific tokens first.
replacements=(
  "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO=${GITHUB_REPO}"
  "@YOUR_GITHUB_ORG/platform-team=${CODEOWNERS}"
  "YOUR_GITHUB_ORG=${GITHUB_OWNER}"
  "YOUR_GITHUB_REPO=${GITHUB_NAME}"
  "stchangemetfstate=st${PREFIX}tfstate"
  "CHANGEME=${PREFIX}"
)
[[ "$REGION" != "eu-west-1" ]] && replacements+=("eu-west-1=${REGION}")
[[ "$AZURE_LOCATION" != "westeurope" ]] && replacements+=("westeurope=${AZURE_LOCATION}")

changed=0
for f in "${files[@]}"; do
  matched=false
  for pair in "${replacements[@]}"; do
    if grep -qF -- "${pair%%=*}" "$f"; then matched=true; break; fi
  done
  $matched || continue
  changed=$((changed + 1))
  if $DRY_RUN; then
    echo "would edit: $f"
    continue
  fi
  for pair in "${replacements[@]}"; do
    FROM="${pair%%=*}" TO="${pair#*=}" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$f"
  done
done

# Region directories: aws/accounts/<env>/eu-west-1 and azure/<env>/westeurope.
rename_dirs() { # rename_dirs <glob-parent-pattern> <from> <to>
  local from="$2" to="$3" d
  for d in $1; do
    [[ -d "$d/$from" ]] || continue
    if $DRY_RUN; then
      echo "would rename: $d/$from -> $d/$to"
    else
      git mv "$d/$from" "$d/$to"
    fi
  done
}
[[ "$REGION" != "eu-west-1" ]] && rename_dirs "aws/accounts/*" "eu-west-1" "$REGION"
[[ "$AZURE_LOCATION" != "westeurope" ]] && rename_dirs "azure/*" "westeurope" "$AZURE_LOCATION"

echo ""
if $DRY_RUN; then
  echo "Dry run: $changed file(s) would change."
  exit 0
fi
echo "Rewrote $changed file(s)."

leftovers=$(git grep -nE 'CHANGEME|YOUR_GITHUB_(ORG|REPO)|stchangemetfstate' -- . ":(exclude)$SELF" ":(exclude).claude/skills/terraform-skill" || true)
if [[ -n "$leftovers" ]]; then
  echo ""
  echo "WARNING: placeholders still present (edit by hand):"
  echo "$leftovers"
fi

if [[ "$REGION" == "us-east-1" ]]; then
  echo ""
  echo "NOTE: your primary region is us-east-1, which the hardening roots already"
  echo "cover with their default provider. Delete the aws.primary provider and the"
  echo "*.primary resources in aws/accounts/*/hardening/."
fi

cat <<EOF

Next:
  1. Check the availability-zone names in aws/accounts/*/${REGION}/01-foundation/main.tf
     exist in your region (aws ec2 describe-availability-zones --region ${REGION}).
  2. Review: git diff --stat && git diff
  3. Commit on a branch, open a PR, and continue with SETUP.md, step 4.
EOF
