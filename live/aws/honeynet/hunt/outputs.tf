output "hunt_vpc_id" {
  description = "ID of the hunt VPC"
  value       = module.vpc.vpc_id
}

output "hunt_host_instance_id" {
  description = "Instance ID of the Hunt Host. Connect with: aws ssm start-session --target <id>."
  value       = module.hunt_host.id
}

output "hunt_host_role_arn" {
  description = "ARN of the Hunt Host instance role"
  value       = module.hunt_host_role.arn
}

output "ssm_scratch_bucket_name" {
  description = "Name of the S3 scratch bucket for the aws_ssm Ansible connection plugin"
  value       = module.ssm_scratch.s3_bucket_id
}

output "ssm_scratch_bucket_region" {
  description = "Region of the S3 scratch bucket"
  value       = module.ssm_scratch.s3_bucket_region
}
