resource "aws_rolesanywhere_trust_anchor" "this" {
  name    = var.name
  enabled = true

  source {
    source_type = "CERTIFICATE_BUNDLE"

    source_data {
      x509_certificate_data = var.ca_certificate_pem
    }
  }

  tags = var.tags
}

resource "aws_rolesanywhere_profile" "this" {
  name             = var.name
  enabled          = var.profile_enabled
  role_arns        = var.role_arns
  duration_seconds = var.session_duration_seconds

  tags = var.tags
}
