output "trust_anchor_arn" {
  description = "ARN of the trust anchor"
  value       = aws_rolesanywhere_trust_anchor.this.arn
}

output "profile_arn" {
  description = "ARN of the profile"
  value       = aws_rolesanywhere_profile.this.arn
}
