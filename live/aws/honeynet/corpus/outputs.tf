output "corpus_bucket_name" {
  description = "Name of the Corpus bucket"
  value       = module.corpus.s3_bucket_id
}

output "corpus_bucket_arn" {
  description = "ARN of the Corpus bucket"
  value       = module.corpus.s3_bucket_arn
}

output "corpus_bucket_regional_domain_name" {
  description = "Regional domain name of the Corpus bucket"
  value       = module.corpus.s3_bucket_bucket_regional_domain_name
}

output "sensor_trust_anchor_arn" {
  description = "ARN of the Roles Anywhere trust anchor for the Sensor CA"
  value       = module.sensor_roles_anywhere.trust_anchor_arn
}

output "sensor_profile_arn" {
  description = "ARN of the Roles Anywhere profile that issues the Sensor sessions"
  value       = module.sensor_roles_anywhere.profile_arn
}

output "sensor_writer_role_arn" {
  description = "ARN of the write-only IAM role that the Sensor assumes"
  value       = module.sensor_writer_role.arn
}

output "ansible_inventory" {
  description = "Corpus values that the Sensor configuration and the verification run read"
  value = {
    sensors = {
      vars = {
        corpus_bucket_name             = module.corpus.s3_bucket_id
        corpus_region                  = data.aws_region.current.region
        corpus_sensor_trust_anchor_arn = module.sensor_roles_anywhere.trust_anchor_arn
        corpus_sensor_profile_arn      = module.sensor_roles_anywhere.profile_arn
        corpus_sensor_role_arn         = module.sensor_writer_role.arn
        corpus_credential_common_name  = var.sensor_certificate_common_name
      }
    }
  }
}
