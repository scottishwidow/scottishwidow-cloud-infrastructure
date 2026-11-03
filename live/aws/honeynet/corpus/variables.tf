variable "aws_region" {
  type        = string
  description = "AWS Region to deploy to"
  default     = "eu-central-1"
}

variable "tags" {
  description = "Tags applied to all resources in this root"
  type        = map(string)
  default = {
    env        = "honeynet"
    management = "terraform"
    Name       = "corpus"
  }
}

variable "corpus_bucket_prefix" {
  description = "Name prefix for the Corpus bucket. The account ID, region, and `-an` namespace suffix are appended (final name: <prefix>-<account-id>-<region>-an)."
  type        = string
  default     = "scottishwidow-honeynet-corpus"
}

variable "corpus_retention_days" {
  description = "Days after which a retained telemetry object expires. The default is 13 months."
  type        = number
  default     = 396

  validation {
    condition     = var.corpus_retention_days >= 1
    error_message = "Retention must be at least 1 day."
  }
}

variable "corpus_noncurrent_version_retention_days" {
  description = "Days after which a non-current object version expires. A version only exists when an object is overwritten, so it is kept for less time than the object itself."
  type        = number
  default     = 30

  validation {
    condition     = var.corpus_noncurrent_version_retention_days >= 1
    error_message = "Non-current version retention must be at least 1 day."
  }
}

variable "corpus_abort_incomplete_multipart_upload_days" {
  description = "Days after which an incomplete multipart upload is aborted and its parts are deleted."
  type        = number
  default     = 7

  validation {
    condition     = var.corpus_abort_incomplete_multipart_upload_days >= 1
    error_message = "Abort after must be at least 1 day."
  }
}

variable "sensor_public_ipv4" {
  description = "Public IPv4 of the Sensor. The writer role trust policy accepts a session only from this address. `make corpus-vars` writes it from the `bootstrap` output."
  type        = string

  validation {
    condition     = can(cidrhost("${var.sensor_public_ipv4}/32", 0))
    error_message = "The Sensor address must be one IPv4 address."
  }
}

variable "sensor_ca_certificate_path" {
  description = "Path to the PEM certificate of the Sensor CA. The CA is generated on the workstation at each provisioning, and the trust anchor takes this certificate as its bundle."
  type        = string
  default     = "../../../hetzner/honeynet/pki/ca.crt"
}

variable "sensor_writer_name" {
  description = "Name of the Roles Anywhere trust anchor, profile, and IAM role that let the Sensor write to the Corpus"
  type        = string
  default     = "honeynet-sensor-corpus-writer"
}

variable "sensor_writer_profile_enabled" {
  description = "Whether the Roles Anywhere profile issues sessions. Set to false to revoke every Sensor certificate, because there is no CRL."
  type        = bool
  default     = true
}

variable "sensor_writer_session_duration_seconds" {
  description = "Lifetime of the credentials that one Roles Anywhere session issues"
  type        = number
  default     = 3600

  validation {
    condition     = var.sensor_writer_session_duration_seconds >= 900 && var.sensor_writer_session_duration_seconds <= 43200
    error_message = "Session duration must be between 900 and 43200 seconds."
  }
}
