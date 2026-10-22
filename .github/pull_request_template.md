## What and why

<!-- What changes, which roots, and why. Link the issue / ticket. -->

## Roots touched

<!-- One line per root, in apply order (01 -> 02 -> 03). -->

- `aws/accounts/<env>/<region>/<NN-tier>/...`

## Plan review

- [ ] I read every plan comment CI posted, not just the summary line.
- [ ] Every change in each plan is explained by this PR's diff. Chatops applies
      the **whole root**, so anything unexpected (drift, someone else's
      unmerged change) would ride along.
- [ ] No unexpected `destroy` or `-/+ replace`. Expected ones are called out above.
- [ ] Renames use `moved {}` blocks (no destroy/recreate of live resources).

## Guardrails

- [ ] `pre-commit run --all-files` passes locally.
- [ ] No new checkov/trivy suppressions, or each one carries an inline justification.
- [ ] No secrets in variables, tfvars, outputs or plan output.

## Apply

<!--
After approval, comment on this PR (first line only; notes may follow):
  terraform apply <dir>
Apply tiers in order, then merge once every root is applied green.
-->
