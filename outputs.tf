output "vpc_id" {
  description = "ID of the project VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  description = "Private RDS endpoint (keep confidential)"
  value       = aws_db_instance.db.address
}

output "app_instance_id" {
  description = "Private application EC2 instance ID"
  value       = aws_instance.app.id
}
