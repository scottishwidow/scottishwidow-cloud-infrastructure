locals {
  corpus_bucket_name = format("%s-%s-%s-an", var.corpus_bucket_prefix, data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  corpus_bucket_arn  = "arn:aws:s3:::${local.corpus_bucket_name}"

  ssm_scratch_bucket_name = format("%s-%s-%s-an", var.ssm_scratch_bucket_prefix, data.aws_caller_identity.current.account_id, data.aws_region.current.region)
}
