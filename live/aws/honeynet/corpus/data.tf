data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "hcloud_primary_ip" "sensor" {
  name = var.sensor_ipv4_name
}
