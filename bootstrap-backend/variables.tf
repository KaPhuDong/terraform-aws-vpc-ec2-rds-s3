variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Prefix for backend resources"
  type        = string
  default     = "dong-w8-mon"
}
