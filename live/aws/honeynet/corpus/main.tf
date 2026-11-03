module "corpus" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket           = format("%s-%s-%s-an", var.corpus_bucket_prefix, data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_deny_insecure_transport_policy = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = true
    }
  }

  lifecycle_rule = [
    {
      id      = "expire-retained-telemetry"
      enabled = true
      filter  = {}

      expiration = {
        days = var.corpus_retention_days
      }

      noncurrent_version_expiration = {
        days = var.corpus_noncurrent_version_retention_days
      }

      abort_incomplete_multipart_upload_days = var.corpus_abort_incomplete_multipart_upload_days
    }
  ]

  tags = var.tags
}

module "sensor_roles_anywhere" {
  source = "../../../../modules/iam_roles_anywhere"

  name                     = var.sensor_writer_name
  ca_certificate_pem       = file(pathexpand(var.sensor_ca_certificate_path))
  role_arns                = [module.sensor_writer_role.arn]
  profile_enabled          = var.sensor_writer_profile_enabled
  session_duration_seconds = var.sensor_writer_session_duration_seconds

  tags = var.tags
}

module "sensor_writer_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = var.sensor_writer_name
  use_name_prefix = false

  trust_policy_permissions = {
    RolesAnywhereFromSensorAddress = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
        "sts:SetSourceIdentity",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["rolesanywhere.amazonaws.com"]
      }]
      condition = [
        {
          test     = "ArnEquals"
          variable = "aws:SourceArn"
          values   = [module.sensor_roles_anywhere.trust_anchor_arn]
        },
        {
          test     = "IpAddress"
          variable = "aws:SourceIp"
          values   = ["${var.sensor_public_ipv4}/32"]
        },
      ]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    CorpusWriteOnly = {
      actions = [
        "s3:PutObject",
        "s3:AbortMultipartUpload",
      ]
      resources = ["${module.corpus.s3_bucket_arn}/*"]
    }
  }

  tags = var.tags
}
