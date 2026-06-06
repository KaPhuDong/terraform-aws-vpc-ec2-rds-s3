output "state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  description = "Backend config values for ../backend.hcl"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "w8/mon/vpc-ec2-rds-s3-lab/terraform.tfstate"
    region         = var.region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = true
  }
}
