data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  az1 = data.aws_availability_zones.available.names[0]
  az2 = data.aws_availability_zones.available.names[1]
  common_tags = {
    Project = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "${var.project_name}-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az1
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "public-a" })
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = local.az2
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "public-b" })
}
resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = local.az1
  tags = merge(local.common_tags, { Name = "private-app-a" })
}
resource "aws_subnet" "app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = local.az2
  tags = merge(local.common_tags, { Name = "private-app-b" })
}
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = local.az1
  tags = merge(local.common_tags, { Name = "private-db-a" })
}
resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = local.az2
  tags = merge(local.common_tags, { Name = "private-db-b" })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = merge(local.common_tags, { Name = "${var.project_name}-nat-eip" })
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.igw]
  tags = merge(local.common_tags, { Name = "${var.project_name}-nat" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id }
  tags = merge(local.common_tags, { Name = "public-rt" })
}
resource "aws_route_table_association" "public_a" {
  subnet_id = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id }
  tags = merge(local.common_tags, { Name = "private-app-rt" })
}
resource "aws_route_table_association" "app_a" {
  subnet_id = aws_subnet.app_a.id
  route_table_id = aws_route_table.private_app.id
}
resource "aws_route_table_association" "app_b" {
  subnet_id = aws_subnet.app_b.id
  route_table_id = aws_route_table.private_app.id
}
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "private-db-rt" })
}
resource "aws_route_table_association" "db_a" {
  subnet_id = aws_subnet.db_a.id
  route_table_id = aws_route_table.private_db.id
}
resource "aws_route_table_association" "db_b" {
  subnet_id = aws_subnet.db_b.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow web HTTP from internet"
  vpc_id      = aws_vpc.main.id
  ingress { from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "App accepts HTTP only from ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 80
  to_port = 80
  protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Database accepts MySQL only from application SG"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 3306
  to_port = 3306
  protocol = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  egress { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}

resource "aws_lb" "app" {
  name               = "capstone-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags = local.common_tags
}
resource "aws_lb_target_group" "app" {
  name     = "capstone-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check { path = "/" }
  tags = local.common_tags
}
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.app_a.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!doctype html>
    <html><head><title>Cloud Security Capstone</title></head>
    <body><h1>Secure Three-Tier Application</h1><p>Served from a private EC2 instance behind an Application Load Balancer.</p></body></html>
    HTML
    systemctl start nginx
  EOF
  user_data_replace_on_change = true
  tags = merge(local.common_tags, { Name = "${var.project_name}-app-server" })
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]
  tags = local.common_tags
}
resource "aws_db_instance" "db" {
  identifier              = "capstone-private-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "capstonedb"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project_name}/flow-logs"
  retention_in_days = 7
  tags = local.common_tags
}
resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-flowlogs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}
resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-flowlogs-policy"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"],
      Resource = "*"
    }]
  })
}
resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  depends_on = [aws_iam_role_policy.flow_logs]
  tags = local.common_tags
}

resource "aws_cloudtrail" "trail" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  tags = local.common_tags
}
resource "aws_s3_bucket" "trail" {
  bucket        = "${var.project_name}-trail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags = local.common_tags
}
data "aws_caller_identity" "current" {}
resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "AWSCloudTrailAclCheck", Effect = "Allow",
      Principal = { Service = "cloudtrail.amazonaws.com" },
      Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.trail.arn,
      Condition = { StringEquals = { "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${aws_cloudtrail.trail.name}" } }
    },{
      Sid = "AWSCloudTrailWrite", Effect = "Allow",
      Principal = { Service = "cloudtrail.amazonaws.com" },
      Action = "s3:PutObject", Resource = "${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${aws_cloudtrail.trail.name}" } }
    }]
  })
}
