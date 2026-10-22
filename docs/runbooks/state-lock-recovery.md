# State lock recovery

**Symptom:** `Error acquiring the state lock` with a lock ID, on a plan or
apply, when you are sure nothing is running against that root.

S3 native locking (`use_lockfile = true`) writes `<key>.tflock` next to the
state object. A run that is killed mid-operation (cancelled job, runner
timeout) leaves it behind.

1. **Make sure nothing is running.** Check Actions for in-progress chatops
   applies or plans on that root (`Apply: <dir>`, `Plan: <dir>`), and ask
   whoever might be running locally. Breaking a live lock can corrupt state.
2. **Read the lock** to see who/what took it and when:

   ```bash
   aws s3 cp s3://<prefix>-tfstate-<env>/<key>.tflock - | jq .
   ```

3. **Release it** with the lock ID from the error, as a human with access to
   that account's state bucket (Claude is denied `force-unlock` here):

   ```bash
   terraform -chdir=<root> init
   terraform -chdir=<root> force-unlock <LOCK_ID>
   ```

4. **Re-plan** (`terraform plan <dir>` comment) and check the plan matches
   expectations before any apply: if the interrupted run was an apply, some
   changes may already be live.

Prevention already in place: drift plans run with `-lock=false`; PR and
apply plans use `-lock-timeout=10m` so contention waits instead of failing;
apply concurrency groups never cancel in-progress runs.
