output "state_buckets" {
  description = "Terraform state bucket name per member account. Each account's roots use theirs in backend.tf."
  value = {
    production = module.state_bucket_production.s3_bucket_id
    staging    = module.state_bucket_staging.s3_bucket_id
    sandbox    = module.state_bucket_sandbox.s3_bucket_id
  }
}

output "state_kms_key_arns" {
  description = "KMS key ARN encrypting each member account's state bucket."
  value = {
    production = module.state_kms_production.key_arn
    staging    = module.state_kms_staging.key_arn
    sandbox    = module.state_kms_sandbox.key_arn
  }
}
