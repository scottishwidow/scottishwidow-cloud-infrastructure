variable "aws_region" {
  type        = string
  description = "AWS Region to deploy to"
  default     = "eu-central-1"
}

variable "tags" {
  description = "Tags applied to all resources in this root. They must not match the management VPC data source in the Nextcloud root."
  type        = map(string)
  default = {
    env        = "honeynet"
    management = "terraform"
    Name       = "hunt"
  }
}

variable "hunt_vpc_cidr_block" {
  description = "CIDR block of the hunt VPC"
  type        = string
  default     = "10.40.0.0/26"
}

variable "hunt_subnet_cidr_blocks" {
  description = "CIDR blocks of the four hunt subnets. The VPC module requires two public and two private subnets. The Hunt Host uses public_1."
  type = object({
    public_1  = string
    public_2  = string
    private_1 = string
    private_2 = string
  })
  default = {
    public_1  = "10.40.0.0/28"
    public_2  = "10.40.0.16/28"
    private_1 = "10.40.0.32/28"
    private_2 = "10.40.0.48/28"
  }
}

variable "hunt_availability_zone" {
  description = "The one availability zone for every hunt subnet"
  type        = string
  default     = "eu-central-1a"
}

variable "hunt_host_name" {
  description = "Name of the Hunt Host instance and the prefix of its supporting resources"
  type        = string
  default     = "hunt-host"
}

variable "hunt_host_instance_type" {
  description = "EC2 instance type of the Hunt Host. It must be arm64, to match the AMI in data.tf."
  type        = string
  default     = "t4g.medium"
}

variable "hunt_host_volume_size_gb" {
  description = "Size of the gp3 root volume that holds the DuckDB database file and the DuckDB temp directory"
  type        = number
  default     = 20
}

variable "corpus_bucket_prefix" {
  description = "Name prefix of the Corpus bucket. It must match the prefix in the `corpus` root."
  type        = string
  default     = "scottishwidow-honeynet-corpus"
}

variable "ssm_scratch_bucket_prefix" {
  description = "Name prefix for the aws_ssm scratch bucket of the Hunt Ansible. The account ID, region, and `-an` namespace suffix are appended (final name: <prefix>-<account-id>-<region>-an)."
  type        = string
  default     = "scottishwidow-hunt-ssm-scratch"
}

variable "ssm_scratch_expiration_days" {
  description = "Days after which scratch-bucket objects (and stalled multipart uploads) are expired. Contents are transient transfer artifacts."
  type        = number
  default     = 1

  validation {
    condition     = var.ssm_scratch_expiration_days >= 1
    error_message = "Lifecycle expiration must be at least 1 day."
  }
}
