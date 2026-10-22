# Vendored skill — provenance

This directory is a **vendored copy** of an upstream Claude Code skill. It is
checked into this repo so every teammate using Claude Code gets the same
Terraform guidance with zero per-person setup.

| Field | Value |
|-------|-------|
| Upstream | https://github.com/antonbabenko/terraform-skill |
| Author | Anton Babenko |
| Version | `1.17.1` |
| Upstream tag commit | `b59d2be9ff4db8f835c8459e05e325ba11e3a21f` |
| Released | 2026-06-03 |
| License | Apache-2.0 (see `LICENSE`) |
| Vendored on | 2026-07-16 |

## What was copied

From the upstream tag: `skills/terraform-skill/SKILL.md`,
`skills/terraform-skill/references/` (8 files), top-level `tests/`, `LICENSE`,
and `CHANGELOG.md`.

## What was intentionally NOT copied

Upstream `.git/`, `.github/`, `.codex-plugin/`, `mcp.json`, `POWER.md`,
`version.json`, `assets/`, `.markdownlint.json`, and the repo-level
`CLAUDE.md` / `CONTRIBUTING.md` / `README.md` (plugin/marketplace/skill-dev
scaffolding that would collide with this repo's own files). The skill is fully
self-contained from `SKILL.md` + `references/`.

## Fidelity

These files are **byte-identical** to the upstream `v1.17.1` tag (verified with
`cmp`). To keep them that way, the repo's `trailing-whitespace` and
`end-of-file-fixer` pre-commit hooks exclude `^\.claude/skills/terraform-skill/`
(see [.pre-commit-config.yaml](../../../.pre-commit-config.yaml)) so they don't
rewrite vendored content. Re-verify after any bump:

```bash
gh api repos/antonbabenko/terraform-skill/tarball/v1.17.1 | tar -xz -C /tmp/v --strip-components=1
diff -r /tmp/v/skills/terraform-skill .claude/skills/terraform-skill   # SKILL.md + references/
```

## Updating

Re-vendor by copying file contents from a newer upstream tag and bumping the
table above — treat it as a routine dependency PR. Do **not** `git clone` into
this directory (no nested `.git`). Upstream layout note: since ~v1.14 the skill
lives under `skills/terraform-skill/` in the source repo; copy that subtree's
contents to this directory's root.
