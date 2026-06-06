# VPC + EC2 + RDS + S3 Terraform Lab

This lab deploys a small AWS web application platform:

- VPC with public and private subnets
- EC2 web server in a public subnet
- RDS MySQL in private subnets
- S3 bucket for static assets
- Security groups that only allow required traffic
- Remote Terraform state stored in S3 with DynamoDB state locking

## Architecture

```text
Internet
   |
Internet Gateway
   |
Public Subnet
   |
EC2 Web Server  ----->  S3 Static Assets Bucket
   |
Security Group rule: MySQL only from Web SG
   |
Private Subnets
   |
RDS MySQL
```

## Backend Bootstrap

Terraform cannot create its own remote state backend in the same run that uses it. Run the bootstrap stack first:

```powershell
cd cloud/w8/mon/vpc-ec2-rds-s3-lab/bootstrap-backend
terraform init
terraform apply
```

Copy the output values into `../backend.hcl`:

```hcl
bucket         = "replace-with-bootstrap-output"
key            = "w8/mon/vpc-ec2-rds-s3-lab/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "replace-with-bootstrap-output"
encrypt        = true
```

## Deploy Lab

```powershell
cd ..
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Cleanup

Destroy the application stack before destroying the backend:

```powershell
terraform destroy
cd bootstrap-backend
terraform destroy
```
