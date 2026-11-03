variable "name" {
  description = "Name of the trust anchor and of the profile"
  type        = string
}

variable "ca_certificate_pem" {
  description = "PEM certificate of the external CA that the trust anchor registers as its certificate bundle"
  type        = string
}

variable "role_arns" {
  description = "ARNs of the IAM roles that the profile maps to. Each role trust policy must trust `rolesanywhere.amazonaws.com`."
  type        = list(string)

  validation {
    condition     = length(var.role_arns) >= 1
    error_message = "The profile must map to at least one role."
  }
}

variable "profile_enabled" {
  description = "Whether the profile issues sessions. Set to false to revoke every certificate, because the trust anchor has no CRL."
  type        = bool
  default     = true
}

variable "session_duration_seconds" {
  description = "Lifetime of the credentials that one session issues"
  type        = number
  default     = 3600

  validation {
    condition     = var.session_duration_seconds >= 900 && var.session_duration_seconds <= 43200
    error_message = "Session duration must be between 900 and 43200 seconds."
  }
}

variable "tags" {
  description = "Tags applied to the trust anchor and the profile"
  type        = map(string)
  default     = {}
}
