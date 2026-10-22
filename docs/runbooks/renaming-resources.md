# Renaming resources without recreating them

Changing a resource's **address** (its label, `for_each` key, or moving it in
or out of a module) looks to Terraform like "destroy the old one, create a new
one". For a database, bucket, DNS record, EIP or load balancer that's an
outage or data loss.

## Within one root: `moved {}`

```hcl
moved {
  from = aws_s3_bucket.bucket
  to   = aws_s3_bucket.app_data
}

moved {
  from = aws_iam_role.task["api"]
  to   = module.api.aws_iam_role.task
}
```

Ship the rename and the `moved` block in the same PR. The plan must show
`has moved to` and **no** destroy/create for those resources. Keep the block
for a while (other branches may still use the old address), then delete it
in a later PR.

## Renaming vs changing the name argument

`moved` changes the Terraform address only. Changing an argument that is the
cloud resource's *name* (`name`, `bucket`, `identifier`, SG `name`/
`description`, ...) is usually `ForceNew`: the plan says `# forces
replacement`. That is a real recreate, which `moved` can't help with. Either
keep the old name or migrate deliberately (create new, move traffic/data,
delete old).

## Between roots

`moved` doesn't cross state files. Use an `import` block in the destination
root and a `removed { lifecycle { destroy = false } }` block in the source
root, applied in that order:

```hcl
# destination root
import {
  to = aws_route53_record.api
  id = "Z123..._api.example.com_A"
}

# source root (after the destination applied)
removed {
  from = aws_route53_record.api
  lifecycle {
    destroy = false
  }
}
```

Both plans must show no destroy of the real resource.
