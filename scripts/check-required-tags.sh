#!/usr/bin/env bash
#
# Required-tags gate for the standardized tag taxonomy.
#
# Tags are applied via the AWS provider `default_tags` block (not per-resource),
# so this validates the source of truth: every `default_tags { tags = { ... } }`
# block in every AWS providers.tf must declare all mandatory keys. Wired into
# pre-commit (.pre-commit-config.yaml) and CI (the "Required Tags" job), so the
# build fails when a root ships an AWS provider without the standardized tags.
#
# Scans ALL aws/**/providers.tf (a repo-wide invariant) regardless of which
# files pre-commit passes. The taxonomy is documented in aws/README.md#tags.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 <<'PY'
import glob
import re
import sys

REQUIRED = ["ManagedBy", "Repository", "Environment", "Region", "Product", "Tier"]


def default_tags_blocks(text):
    """Yield the source of each brace-matched `default_tags { ... }` block."""
    for m in re.finditer(r"default_tags\s*\{", text):
        depth, i = 0, m.end() - 1
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    yield text[m.start():i + 1]
                    break
            i += 1


failures = 0
files = sorted(glob.glob("aws/**/providers.tf", recursive=True))

for path in files:
    with open(path) as fh:
        text = fh.read()

    found = False
    for block in default_tags_blocks(text):
        found = True
        keys = set(re.findall(r"(?m)^\s*([A-Za-z0-9_]+)\s*=", block))
        missing = [k for k in REQUIRED if k not in keys]
        if missing:
            failures += 1
            print(f"::error file={path}::default_tags missing required key(s): {', '.join(missing)}")
            print(f"  {path}: default_tags missing {missing}", file=sys.stderr)

    # An aws provider with no default_tags block at all is also a violation.
    if not found and re.search(r'provider\s+"aws"', text):
        failures += 1
        print(f"::error file={path}::aws provider has no default_tags block")
        print(f"  {path}: aws provider has no default_tags block", file=sys.stderr)

if failures:
    print(
        f"\nRequired-tags check FAILED: {failures} provider block(s) missing mandatory tags.",
        file=sys.stderr,
    )
    print(f"Every aws default_tags block must set: {', '.join(REQUIRED)}", file=sys.stderr)
    sys.exit(1)

print(f"Required-tags check passed: {len(files)} providers.tf scanned, all default_tags complete.")
PY
