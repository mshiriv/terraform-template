# Provider regression

**Symptom:** plans start failing across many roots at once, with errors that
have nothing to do with recent changes (malformed requests, panics, new
validation errors), usually the day a provider release ships.

Because `.terraform.lock.hcl` is not committed (see "Known gaps" in
CLAUDE.md), every CI `init` resolves the newest version matching `~> X.0`, so
a bad release reaches every root immediately.

1. **Confirm.** The failing jobs' `terraform init` output shows the provider
   version installed. Compare with the last green run, and check the
   provider's GitHub issues/releases.
2. **Exclude the bad release** in every affected `providers.tf`:

   ```hcl
   aws = {
     source  = "hashicorp/aws"
     version = "~> 6.0, != 6.57.0"
   }
   ```

   ```bash
   grep -rl 'hashicorp/aws' --include=providers.tf aws | xargs \
     perl -pi -e 's/version = "~> 6.0"/version = "~> 6.0, != 6.57.0"/'
   ```

3. Open the PR; plans should go green on the previous release.
4. **Remove the exclusion** once a fixed release is out (or leave it: it's
   harmless), in a follow-up PR.

The durable fix is committing multi-platform lockfiles; see "Known gaps" in
CLAUDE.md.
