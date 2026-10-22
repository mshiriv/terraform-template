#!/usr/bin/env bash
#
# Claude Code PostToolUse hook: run `terraform fmt` on every .tf / .tfvars file
# Claude writes, so edits land formatted and the terraform_fmt pre-commit hook
# never has to bounce them. Wired in .claude/settings.json.
#
# Input: the hook payload as JSON on stdin (we read .tool_input.file_path).
# Exit 0 = nothing to say; exit 2 = stderr is shown to Claude (fmt found a
# syntax error it should fix).

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v terraform >/dev/null 2>&1 || exit 0

file=$(jq -r '.tool_input.file_path // empty')

case "$file" in
  *.tf | *.tfvars | *.tftest.hcl) ;;
  *) exit 0 ;;
esac

[[ -f "$file" ]] || exit 0

if ! out=$(terraform fmt -no-color "$file" 2>&1); then
  echo "terraform fmt failed on ${file}:" >&2
  echo "$out" >&2
  exit 2
fi
