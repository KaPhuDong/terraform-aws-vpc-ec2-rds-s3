# Lab: AWS VPC + EC2 + RDS + S3 với Terraform

## 1. Mục tiêu bài lab

Bài lab này triển khai một kiến trúc web application cơ bản trên AWS bằng Terraform. Hạ tầng được thiết kế theo mô hình tách lớp:

- Public layer: EC2 web server nằm trong public subnet để nhận traffic từ Internet.
- Private layer: RDS MySQL nằm trong private subnet để không bị truy cập trực tiếp từ Internet.
- Storage layer: S3 bucket dùng để lưu static assets.
- Network layer: VPC, public subnet, private subnet, route table và Internet Gateway.
- Security layer: Security Groups giới hạn traffic cần thiết.
- State management: Terraform state được lưu remote trên S3 và dùng DynamoDB để khóa state.

## 2. Kiến trúc tổng quan

```text
Internet
   |
   v
Internet Gateway
   |
   v
Public Subnet
   |
   v
EC2 Web Server
   |
   | MySQL traffic: port 3306
   v
Private Subnets
   |
   v
RDS MySQL

EC2 Web Server also has IAM permission to access S3 static assets bucket.
```

Trong kiến trúc này:

- EC2 được đặt trong public subnet vì web server cần có public IP để người dùng truy cập qua HTTP.
- RDS được đặt trong private subnets để database không public ra Internet.
- Security Group của RDS chỉ cho phép MySQL traffic từ Security Group của EC2.
- S3 bucket được bật versioning và chặn public access mặc định.
- Terraform state không lưu local lâu dài mà được lưu trong S3 backend.

## 3. Các file đã tạo

Thư mục chính của lab:

```text
cloud/w8/mon/vpc-ec2-rds-s3-lab/
```

Các file chính:

- `README.md`: hướng dẫn nhanh cách bootstrap backend, deploy và cleanup.
- `command.txt`: danh sách lệnh thực hành theo thứ tự.
- `versions.tf`: khai báo Terraform version, provider version và S3 backend.
- `providers.tf`: cấu hình AWS provider.
- `variables.tf`: khai báo biến cấu hình.
- `main.tf`: định nghĩa tài nguyên chính như EC2, RDS, S3, IAM và Security Groups.
- `outputs.tf`: xuất các thông tin sau khi apply như web URL, RDS endpoint, bucket name.
- `user-data.sh.tftpl`: script khởi tạo EC2 web server.
- `backend.hcl.example`: file mẫu để cấu hình remote backend.
- `modules/vpc/`: module riêng để tạo VPC, subnets, route tables và Internet Gateway.
- `bootstrap-backend/`: Terraform stack riêng để tạo S3 bucket và DynamoDB table cho remote state.

## 4. Bước 1: Tạo module VPC

Module VPC nằm trong:

```text
modules/vpc/
```

Module này tạo các thành phần:

- `aws_vpc`: tạo VPC chính với CIDR mặc định `10.20.0.0/16`.
- `aws_internet_gateway`: tạo Internet Gateway để public subnet đi ra Internet.
- `aws_subnet.public`: tạo public subnets.
- `aws_subnet.private`: tạo private subnets.
- `aws_route_table.public`: route table public có route `0.0.0.0/0` đi qua Internet Gateway.
- `aws_route_table.private`: route table private không có route trực tiếp ra Internet.
- Route table associations để gắn subnet với route table phù hợp.

Lý do tách VPC thành module:

- Dễ tái sử dụng cho các lab hoặc môi trường khác.
- Tách phần network khỏi phần compute/database/storage.
- Code rõ ràng hơn khi kiến trúc lớn dần.

## 5. Bước 2: Triển khai EC2 web server

EC2 được định nghĩa trong `main.tf` bằng resource:

```hcl
resource "aws_instance" "web"
```

EC2 được cấu hình:

- Chạy Amazon Linux 2023 AMI mới nhất.
- Dùng instance type mặc định `t3.micro`.
- Đặt trong public subnet đầu tiên.
- Có public IP để truy cập từ Internet.
- Gắn Security Group `web`.
- Gắn IAM instance profile để có quyền truy cập S3 static assets bucket.
- Dùng `user_data` để cài Apache HTTP server và tạo trang `index.html`.

Security Group của web server cho phép:

- HTTP port `80` từ Internet.
- SSH port `22` từ CIDR cấu hình trong biến `allowed_ssh_cidr`.
- Outbound traffic ra ngoài.

## 6. Bước 3: Triển khai RDS MySQL trong private subnet

RDS được định nghĩa bằng resource:

```hcl
resource "aws_db_instance" "mysql"
```

Database được cấu hình:

- Engine: MySQL.
- Engine version: `8.0`.
- Instance class: `db.t3.micro`.
- Allocated storage: `20 GB`.
- Không public ra Internet: `publicly_accessible = false`.
- Đặt trong DB subnet group gồm private subnet IDs.
- Mật khẩu database được generate bằng `random_password`.

Trước khi tạo RDS, lab tạo:

```hcl
resource "aws_db_subnet_group" "mysql"
```

DB subnet group giúp RDS biết database được phép chạy trong các private subnet nào.

Security Group của database chỉ cho phép:

- Inbound MySQL port `3306` từ Security Group của EC2 web server.

Điều này nghĩa là Internet không thể truy cập trực tiếp vào RDS. Chỉ web server mới có quyền kết nối database.

## 7. Bước 4: Tạo S3 bucket cho static assets

S3 bucket được tạo bằng:

```hcl
resource "aws_s3_bucket" "static_assets"
```

Bucket được cấu hình thêm:

- `aws_s3_bucket_versioning`: bật versioning để giữ lịch sử object.
- `aws_s3_bucket_public_access_block`: chặn public ACL và public bucket policy.
- IAM policy cho EC2 được phép `ListBucket`, `GetObject`, `PutObject` trên bucket này.

Bucket name có random suffix để tránh trùng tên toàn cầu trên AWS.

## 8. Bước 5: Cấu hình Security Groups

Lab tạo hai Security Groups chính:

### Web Security Group

Resource:

```hcl
resource "aws_security_group" "web"
```

Cho phép:

- Inbound HTTP port `80` từ `0.0.0.0/0`.
- Inbound SSH port `22` từ biến `allowed_ssh_cidr`.
- Outbound tất cả traffic.

### Database Security Group

Resource:

```hcl
resource "aws_security_group" "database"
```

Cho phép:

- Inbound MySQL port `3306` chỉ từ Web Security Group.
- Outbound tất cả traffic.

Đây là điểm quan trọng của bài lab: database không mở port cho toàn Internet, mà chỉ nhận kết nối từ web server.

## 9. Quản lý Terraform State bằng S3 và DynamoDB

Terraform state là file lưu trạng thái hạ tầng mà Terraform đang quản lý. Nếu nhiều người cùng chạy Terraform với state local, rất dễ xảy ra xung đột hoặc ghi đè state.

Lab này xử lý bằng cách:

- Lưu state trên S3 bucket.
- Dùng DynamoDB table để lock state khi Terraform đang chạy.

Root stack khai báo backend trong `versions.tf`:

```hcl
terraform {
  backend "s3" {}
}
```

Thông tin thật của backend được truyền qua file `backend.hcl` khi chạy:

```powershell
terraform init -backend-config=backend.hcl
```

File `backend.hcl.example` là file mẫu. File `backend.hcl` thật được ignore trong Git vì nó phụ thuộc vào bucket/table đã bootstrap.

## 10. Vì sao cần bootstrap backend riêng?

Terraform không thể dùng S3 backend trước khi S3 bucket đó tồn tại. Vì vậy cần có một stack riêng:

```text
bootstrap-backend/
```

Stack này tạo:

- S3 bucket để lưu Terraform state.
- DynamoDB table để lock state.
- Versioning và encryption cho state bucket.
- Public access block cho state bucket.

Sau khi chạy bootstrap xong, lấy output để tạo file `backend.hcl`, rồi mới init root lab với remote backend.

## 11. Thứ tự chạy lệnh

### Bước 1: Bootstrap remote backend

```powershell
cd cloud/w8/mon/vpc-ec2-rds-s3-lab/bootstrap-backend
terraform init
terraform apply
```

Sau khi apply xong, Terraform sẽ output tên S3 bucket và DynamoDB table.

### Bước 2: Tạo file backend.hcl

```powershell
cd ..
Copy-Item backend.hcl.example backend.hcl
```

Sau đó sửa `backend.hcl` theo output từ bootstrap:

```hcl
bucket         = "actual-state-bucket-name"
key            = "w8/mon/vpc-ec2-rds-s3-lab/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "actual-lock-table-name"
encrypt        = true
```

### Bước 3: Init root stack với S3 backend

```powershell
terraform init -backend-config=backend.hcl
```

### Bước 4: Validate, plan và apply

```powershell
terraform validate
terraform plan
terraform apply
```

### Bước 5: Kiểm tra output

```powershell
terraform output web_url
terraform output rds_endpoint
terraform output static_assets_bucket
```

## 12. Cleanup tài nguyên

Cần destroy theo đúng thứ tự:

### Bước 1: Destroy application stack

```powershell
cd cloud/w8/mon/vpc-ec2-rds-s3-lab
terraform destroy
```

### Bước 2: Destroy backend stack

```powershell
cd bootstrap-backend
terraform destroy
```

Không nên destroy backend trước, vì root stack vẫn cần backend để đọc state khi destroy tài nguyên ứng dụng.

## 13. Những kiểm tra đã thực hiện

Sau khi viết code, đã chạy các lệnh kiểm tra:

```powershell
terraform fmt -recursive cloud\w8\mon\vpc-ec2-rds-s3-lab
```

Lệnh này format toàn bộ Terraform files.

```powershell
terraform init -backend=false
terraform validate
```

Hai lệnh này kiểm tra root stack mà không cần backend S3 thật.

Trong thư mục `bootstrap-backend/` cũng đã chạy:

```powershell
terraform init
terraform validate
```

Kết quả: cả root stack và bootstrap stack đều valid.

## 14. Ghi chú bảo mật

- Private key không được commit lên Git.
- Terraform state không được commit lên Git vì có thể chứa thông tin nhạy cảm.
- File `backend.hcl` thật không commit vì chứa thông tin backend theo môi trường.
- RDS password được generate tự động và output ở dạng sensitive.
- RDS không public ra Internet.
- S3 bucket static assets đang bị block public access mặc định.
