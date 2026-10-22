# tflint's default `signature = "auto"` prefers GitHub artifact attestations, and
# verifying them panics: sigstore-go nil-derefs in bundle.(*Bundle).TlogEntries,
# crashing `tflint --init` before any config is linted. Upstream:
# terraform-linters/tflint#2591 (reproduces on v0.62.1 and v0.63.1, with and
# without GITHUB_TOKEN). "pgp" keeps signature verification rather than
# disabling it ("none"): plugins under the terraform-linters org are checked
# against tflint's built-in key, so no signing_key is needed. Revert to the
# default once #2591 is fixed; tflint warns the PGP key is legacy.
plugin "aws" {
  enabled   = true
  version   = "0.49.0"
  source    = "github.com/terraform-linters/tflint-ruleset-aws"
  signature = "pgp"
}

plugin "azurerm" {
  enabled   = true
  version   = "0.32.0"
  source    = "github.com/terraform-linters/tflint-ruleset-azurerm"
  signature = "pgp"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Disabled: this rule enforces the reusable-module file layout (it requires an
# outputs.tf in every dir). The roots in this repo are leaf compositions, not
# modules; output-less roots (hardening, monitors, ...) legitimately omit
# outputs. Reusable modules belong in a separate modules repo, where the rule
# still applies.
rule "terraform_standard_module_structure" {
  enabled = false
}

# Disabled: data.tf remote-state lookups are scaffolded per tier and are often
# only partly consumed while a root grows.
rule "terraform_unused_declarations" {
  enabled = false
}
