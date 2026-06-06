output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "web_public_ip" {
  description = "Public IP address of the EC2 web server"
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "HTTP URL for the EC2 web server"
  value       = "http://${aws_instance.web.public_dns}"
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "static_assets_bucket" {
  description = "S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.bucket
}

output "db_password" {
  description = "Generated RDS master password"
  value       = random_password.db_password.result
  sensitive   = true
}
