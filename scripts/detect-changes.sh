#!/usr/bin/env bash
#
# detect-changes.sh: detect which Terraform root directories need plan/apply
#
# Usage:
#   ./scripts/detect-changes.sh <base_ref>   # roots changed vs origin/<base_ref>
#   ./scripts/detect-changes.sh --all        # every root CI can plan (drift sweep)
#   ./scripts/detect-changes.sh --check DIR  # exit 0 iff CI may plan/apply DIR
#
# Output: JSON array of Terraform root directories, sorted.
# A "root" is any directory containing a backend.tf. Used by the GitHub Actions
# plan, chatops and drift workflows.

set -euo pipefail

BASE_REF="${1:?Usage: detect-changes.sh <base_ref> | --all | --check <dir>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Single source of truth for which roots CI may plan. The PR/chatops diff mode
# and the drift --all mode both filter through this, so the two lists cannot
# diverge.
#
# Never planned by the main CI matrix (all are still linted by pre-commit):
#   aws/bootstrap    spans several accounts with aliased providers and needs
#                    runtime vars; applied by scripts/bootstrap.sh.
#   azure/bootstrap  runs once against a local backend, then migrates state to
#                    the storage account it creates.
#   github/*         manage GitHub itself and need an admin-scoped token;
#                    planned by github-roots-plan.yml, applied out-of-band.
#   <root>/.ci-skip  opt-out marker for a root CI runners can't reach (e.g. a
#                    database-users root whose provider must connect to a
#                    private endpoint). Put the reason and the out-of-band
#                    apply procedure in the marker file / the root's README.
is_ci_root() {
  case "$1" in
    aws/bootstrap | azure/bootstrap | github/*) return 1 ;;
  esac
  [[ ! -f "$REPO_ROOT/$1/.ci-skip" ]]
}

if [[ "$BASE_REF" == "--check" ]]; then
  if is_ci_root "${2:?Usage: detect-changes.sh --check <dir>}"; then exit 0; fi
  exit 1
fi

to_json() {
  sort -u | jq -R -s -c 'split("\n") | map(select(. != ""))'
}

if [[ "$BASE_REF" == "--all" ]]; then
  cd "$REPO_ROOT"
  # Only search the cloud trees that exist: an adopter may delete azure/ etc.
  trees=()
  for t in aws azure datadog github; do
    if [[ -d "$t" ]]; then trees+=("$t"); fi
  done
  if [[ ${#trees[@]} -eq 0 ]]; then
    echo '[]'
    exit 0
  fi
  find "${trees[@]}" -name backend.tf -type f -not -path '*/.terraform/*' \
    | sed 's|/backend.tf$||' \
    | while read -r dir; do
        if is_ci_root "$dir"; then echo "$dir"; fi
      done \
    | to_json
  exit 0
fi

# Get all changed files relative to the base ref
CHANGED_FILES=$(git diff --name-only "origin/${BASE_REF}...HEAD" 2>/dev/null ||
  git diff --name-only "HEAD~1...HEAD")

# Newline-separated sets (deduplicated by to_json / sort -u). Plain strings
# rather than associative arrays keep this runnable on macOS's bash 3.2.
AFFECTED_DIRS=""
REMOVED_DIRS=""
NOTED_REMOVALS=""

# Roots intentionally removed and verified to have NO remote state / resources
# to orphan, so the removed-root guardrail below would be a false positive.
# Listing a path here is the explicit human acknowledgement the guardrail asks
# for. Prune the entry after the removal PR merges (it's inert once the root is
# gone at base). Example:
#   "aws/accounts/sandbox/eu-west-1/03-workloads/old-app"  # never applied
ACKNOWLEDGED_REMOVALS=(
)

is_acknowledged_removal() {
  local d
  # ${arr[@]+...}: expanding an empty array trips `set -u` on bash < 4.4.
  for d in ${ACKNOWLEDGED_REMOVALS[@]+"${ACKNOWLEDGED_REMOVALS[@]}"}; do
    [[ "$d" == "$1" ]] && return 0
  done
  return 1
}

for file in $CHANGED_FILES; do
  # Skip non-relevant files
  case "$file" in
    *.md | .gitignore | .github/CODEOWNERS | .tflint.hcl | .terraform-version) continue ;;
  esac

  # Direct changes to terraform roots
  if [[ "$file" =~ ^(aws|azure|datadog|github)/ ]]; then
    # Walk up from the file to the terraform root (directory containing backend.tf).
    dir=$(dirname "$file")
    while [[ "$dir" != "." ]]; do
      has_now=false
      has_base=false
      [[ -f "$REPO_ROOT/$dir/backend.tf" ]] && has_now=true
      if git cat-file -e "origin/${BASE_REF}:$dir/backend.tf" 2>/dev/null; then
        has_base=true
      fi

      if [[ "$has_now" == true ]]; then
        if is_ci_root "$dir"; then AFFECTED_DIRS+="$dir"$'\n'; fi
        break
      elif [[ "$has_base" == true ]]; then
        # The root existed at the base ref but its backend.tf is gone at HEAD:
        # a deleted or renamed root. Left unhandled, its resources and remote
        # state are orphaned with no plan ever shown. Hard-fail so it's dealt
        # with, unless the removal was explicitly acknowledged above.
        if is_acknowledged_removal "$dir"; then
          case $'\n'"$NOTED_REMOVALS" in
            *$'\n'"$dir"$'\n'*) ;; # already reported (one notice per root, not per file)
            *)
              echo "::notice::Acknowledged removal of Terraform root '$dir' (verified no remote state to orphan)." >&2
              NOTED_REMOVALS+="$dir"$'\n'
              ;;
          esac
        else
          REMOVED_DIRS+="$dir"$'\n'
        fi
        break
      fi
      dir=$(dirname "$dir")
    done
  fi

  # Policy changes affect aws/organization/
  if [[ "$file" =~ ^aws/policies/ ]]; then
    AFFECTED_DIRS+="aws/organization"$'\n'
  fi

  # CI/CD workflow changes: flag but don't trigger TF plans
  if [[ "$file" =~ ^\.github/workflows/ ]]; then
    echo "::warning::CI/CD workflow changed: $file" >&2
  fi
done

# A removed/renamed root must be handled explicitly (teardown, or `moved`/state
# migration for a rename), never silently dropped from the plan matrix.
if [[ -n "$REMOVED_DIRS" ]]; then
  printf '%s' "$REMOVED_DIRS" | sort -u | while read -r d; do
    echo "::error::Terraform root removed or renamed: '$d' (had backend.tf at '${BASE_REF}', gone at HEAD). Its resources and remote state would be orphaned. Tear it down first (see docs/runbooks/removing-a-root.md), or acknowledge it in ACKNOWLEDGED_REMOVALS if it never held state." >&2
  done
  exit 1
fi

# Output as JSON array, sorted for deterministic ordering.
# Sorting puts 01-foundation < 02-platform < 03-workloads (the apply order).
printf '%s' "$AFFECTED_DIRS" | to_json
