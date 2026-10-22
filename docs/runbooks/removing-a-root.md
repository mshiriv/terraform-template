# Removing (or renaming) a root

Deleting a directory that holds a `backend.tf` doesn't delete anything in the
cloud: it orphans the resources and their state. CI therefore **fails any PR
that removes a root** (`Terraform root removed or renamed` in Detect Changes).

## Retire a root

1. **PR 1, empty the root.** Delete the resource and module blocks (keep
   `backend.tf`, `providers.tf`, and any variables the providers need).
   Remove outputs other roots read only after those readers stop using them.
2. Review the plan: it must list exactly the resources you expect under
   *will be destroyed*. Watch for `prevent_destroy` guards (remove them in the
   same PR) and for deletion protection flags on databases/load balancers
   (turn them off in an earlier apply).
3. `terraform apply <dir>`, merge.
4. **PR 2, delete the directory.** The state is now empty, so acknowledge the
   removal in `ACKNOWLEDGED_REMOVALS` in `scripts/detect-changes.sh` (one line,
   with a comment) and delete the directory. Remove the acknowledgement in a
   later PR.
5. Optionally delete the empty state object from the bucket.

Chatops only runs `plan`/`apply`, never `destroy`: emptying the config is the
destroy, and its plan is the review.

## Rename / move a root

Moving a directory changes its backend `key`, so Terraform would see a new,
empty state. Instead:

1. Copy the state to the new key (as a human with access to the bucket):

   ```bash
   aws s3 cp s3://<bucket>/<old-key> s3://<bucket>/<new-key>
   ```

2. PR: move the directory, update `backend.tf`'s `key`, update every
   `terraform_remote_state` that reads the old key, and add the old path to
   `ACKNOWLEDGED_REMOVALS`.
3. The plan for the new path must be **no changes**. Merge, then delete the old
   state object.

A root that was never applied (no state object) can simply be deleted with an
`ACKNOWLEDGED_REMOVALS` entry.
