module "vpc" {
  source = "../../../../modules/vpc"

  region = var.aws_region
  tags   = var.tags

  vpc_cidr_block              = var.hunt_vpc_cidr_block
  public_subnet_cidr_block_1  = var.hunt_subnet_cidr_blocks.public_1
  public_subnet_cidr_block_2  = var.hunt_subnet_cidr_blocks.public_2
  private_subnet_cidr_block_1 = var.hunt_subnet_cidr_blocks.private_1
  private_subnet_cidr_block_2 = var.hunt_subnet_cidr_blocks.private_2

  az_1 = var.hunt_availability_zone
  az_2 = var.hunt_availability_zone
  az_3 = var.hunt_availability_zone
}

module "hunt_host" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.4.1"

  name = var.hunt_host_name

  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.hunt_host_instance_type
  subnet_id                   = module.vpc.public_zone_1
  create_security_group       = false
  vpc_security_group_ids      = [module.hunt_host_sg.id]
  associate_public_ip_address = true

  ignore_ami_changes = true

  root_block_device = {
    type      = "gp3"
    size      = var.hunt_host_volume_size_gb
    encrypted = true
  }

  iam_instance_profile = module.hunt_host_role.instance_profile_name

  tags = var.tags
}

module "hunt_host_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${var.hunt_host_name}-sg"
  description = "Hunt Host: nothing inbound, HTTPS outbound for SSM and S3"
  vpc_id      = module.vpc.vpc_id

  egress_rules = {
    https = {
      description = "HTTPS to the SSM and S3 public endpoints"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      to_port     = 443
    }
  }

  tags = var.tags
}

module "hunt_host_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = var.hunt_host_name
  use_name_prefix = false
  description     = "Instance role for ${var.hunt_host_name}: SSM Session Manager (no SSH) and read-only Corpus access."

  create_instance_profile = true

  trust_policy_permissions = {
    EC2 = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  create_inline_policy = true
  inline_policy_permissions = {
    CorpusList = {
      actions   = ["s3:ListBucket"]
      resources = [local.corpus_bucket_arn]
    }
    CorpusRead = {
      actions   = ["s3:GetObject"]
      resources = ["${local.corpus_bucket_arn}/*"]
    }
  }

  tags = var.tags
}

module "ssm_scratch" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket           = local.ssm_scratch_bucket_name
  bucket_namespace = "account-regional"

  force_destroy = true

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
