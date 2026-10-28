variable "aws_region" {
  description = "AWS region for this lab"
  type        = string
  default     = "ap-south-1"
}
variable "project_name" {
  type    = string
  default = "cloud-security-capstone"
}
variable "my_ip_cidr" {
  description = "Your current public IPv4 CIDR, e.g. 203.0.113.10/32. Used only if you later add admin access."
  type        = string
  default     = "0.0.0.0/32"
}
variable "db_username" {
  type      = string
  default   = "appadmin"
}
variable "db_password" {
  description = "Set through TF_VAR_db_password or a secrets manager; never commit real passwords."
  type        = string
  sensitive   = true
}

variable "app_instance_type" {
  description = "EC2 instance type for the private application server"
  type        = string
  default     = "t3.micro"
}
