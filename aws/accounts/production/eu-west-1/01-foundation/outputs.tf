# Consumed by the 02-platform and 03-workloads roots of this account/region via
# terraform_remote_state. Renaming or removing an output breaks those readers:
# grep for it under aws/accounts/<env>/<region>/ first.

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC primary IPv4 CIDR."
  value       = module.vpc.vpc_cidr_block
}

output "azs" {
  description = "Availability zones the subnets span."
  value       = module.vpc.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancers, NAT)."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private (workload) subnet IDs."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "Isolated database subnet IDs (no route to the internet)."
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "RDS DB subnet group over the database subnets."
  value       = module.vpc.database_subnet_group_name
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateway(s): what third parties allow-list for egress."
  value       = module.vpc.nat_public_ips
}

output "kms_key_arns" {
  description = "KMS key ARN per data class (ebs, rds, s3, general, logs)."
  value       = { for k, m in module.kms : k => m.key_arn }
}
