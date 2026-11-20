module "next_cloud" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.4.1"

  name = var.next_cloud_instance_name

  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.next_cloud_instance_type
  subnet_id                   = data.aws_subnet.public_zone_1.id
  vpc_security_group_ids      = [module.next_cloud_sg.id]
  create_security_group       = false
  associate_public_ip_address = true

  ignore_ami_changes = true

  user_data                   = file("${path.module}/user_data_next_cloud.sh")
  user_data_replace_on_change = true

  root_block_device = {
    type      = "gp3"
    size      = 30
    encrypted = true
  }

  create_eip = true
  eip_domain = "vpc"
  eip_tags   = { Name = var.next_cloud_instance_name }

  create_iam_instance_profile = true
  iam_role_description        = "Instance role for ${var.next_cloud_instance_name}: enables SSM Session Manager (no SSH)."
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    env        = "management"
    management = "terraform"
    Name       = "scottishwidow"
  }
}

module "next_cloud_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${var.next_cloud_instance_name}-sg"
  description = "Nextcloud instance: HTTP/HTTPS inbound only"
  vpc_id      = data.aws_vpc.management.id

  ingress_rules = {
    http = {
      description = "HTTP"
      from_port   = 80
      cidr_ipv4   = "0.0.0.0/0"
    }
    https = {
      description = "HTTPS"
      from_port   = 443
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    all-ipv4 = {
      description = "All protocols"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all-ipv6 = {
      description = "All protocols"
      ip_protocol = "-1"
      cidr_ipv6   = "::/0"
    }
  }

  tags = var.tags
}

# TODO: Remove the moved, removed, and import blocks below after the security-group v6 migration is applied.
# The v5 rules are forgotten and the same AWS rules are imported, so no rule is deleted or duplicated during apply.
moved {
  from = module.next_cloud_sg.aws_security_group.this_name_prefix[0]
  to   = module.next_cloud_sg.aws_security_group.this[0]
}

removed {
  from = module.next_cloud_sg.aws_security_group_rule.ingress_rules

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.next_cloud_sg.aws_security_group_rule.egress_rules

  lifecycle {
    destroy = false
  }
}

import {
  to = module.next_cloud_sg.aws_vpc_security_group_ingress_rule.this["http"]
  id = "sgr-07b48b658ab715fe7"
}

import {
  to = module.next_cloud_sg.aws_vpc_security_group_ingress_rule.this["https"]
  id = "sgr-008e1644450ec254a"
}

import {
  to = module.next_cloud_sg.aws_vpc_security_group_egress_rule.this["all-ipv4"]
  id = "sgr-05f331dbae565b959"
}

import {
  to = module.next_cloud_sg.aws_vpc_security_group_egress_rule.this["all-ipv6"]
  id = "sgr-06ca79c1760b555fa"
}

module "next_cloud_backup" {
  source = "../../../../modules/dlm_backup"

  name        = var.next_cloud_instance_name
  description = "Nextcloud EBS snapshots - ${join(" ", [for s in var.next_cloud_backup_schedules : "${s.retain_count} ${s.name}"])}"

  target_tags = { Name = var.next_cloud_instance_name }
  schedules   = var.next_cloud_backup_schedules

  exclude_boot_volume = false

  snapshot_tags = var.tags
  tags          = var.tags
}

module "ssm_scratch" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.18.0"

  bucket           = format("%s-%s-%s-an", var.ssm_scratch_bucket_prefix, data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

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
      id      = "expire-scratch-objects"
      enabled = true
      filter  = {}

      expiration = {
        days = var.ssm_scratch_expiration_days
      }

      abort_incomplete_multipart_upload_days = var.ssm_scratch_expiration_days
    }
  ]

  tags = var.tags
}
