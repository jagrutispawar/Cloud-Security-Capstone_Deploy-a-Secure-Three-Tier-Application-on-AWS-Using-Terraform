# Cloud Security Capstone — Secure Three-Tier AWS Application with Terraform

**Student:** Kartik Pawar  
**Assignment topic:** Deploy a Secure Three-Tier Application on AWS Using Terraform

## Project objective
Build a secure, scalable three-tier architecture on AWS using Terraform. The project includes a public web entry point, a private application server, and a private database tier.

## Architecture
See [`docs/architecture.png`](docs/architecture.png).

- **Public tier:** Application Load Balancer in two public subnets.
- **Application tier:** Amazon EC2 in a private application subnet; the ALB forwards HTTP traffic to this instance.
- **Database tier:** Amazon RDS for MySQL in private database subnets, with public access disabled.
- **Networking:** VPC, public/private subnets, Internet Gateway, NAT Gateway, route tables, and security groups.
- **Monitoring:** VPC Flow Logs to CloudWatch Logs and a multi-region CloudTrail trail with an S3 destination.

## Security controls
- The RDS instance is configured with `publicly_accessible = false`.
- Database inbound TCP/3306 is allowed only from the application security group.
- Application inbound HTTP/80 is allowed only from the ALB security group.
- The application EC2 instance is placed in a private subnet and does not receive a public IP.
- The CloudTrail S3 bucket blocks public access.

## Repository structure
```text
terraform/       Terraform infrastructure code
docs/            Architecture diagram and final report
screenshots/     Step-wise AWS console reference screenshots supplied for the report
```

## Prerequisites
- Terraform 1.5 or later
- AWS CLI configured for a lab account
- AWS permissions for VPC, EC2, ELB, RDS, IAM, CloudWatch Logs, CloudTrail, and S3

## Deploy
Run from the `terraform/` folder:

```bash
terraform init
terraform fmt -recursive
terraform validate
export TF_VAR_db_password='Use-a-strong-unique-lab-password'
terraform plan
terraform apply
```

Review the plan before confirming. Do not commit credentials, passwords, private keys, or a real `terraform.tfvars` file.

## Verify in AWS Console
1. VPC: verify public and private subnets and route tables.
2. EC2: verify the application instance is in a private subnet and has no public IPv4 address.
3. EC2 > Load Balancers: verify the ALB is active and internet-facing.
4. Target Groups: verify the EC2 target becomes healthy after user data installs Nginx.
5. RDS: verify `Publicly accessible: No`.
6. Security Groups: verify DB inbound TCP/3306 source is the application security group only.
7. VPC > Flow Logs / CloudWatch Logs: verify flow log delivery.
8. CloudTrail: verify the trail is logging and events appear in Event history.

## Important cost and validation notes
AWS resources such as NAT Gateways, ALBs, EC2, and RDS may incur charges. Destroy resources after the lab if you no longer need them:

```bash
terraform destroy
```

Terraform code is a learning project and must be reviewed for current provider/API constraints and account quotas before deployment. Screenshots are reference evidence provided for the report; some examples may show sample resource names, IDs, CIDRs, or regions. They are not proof that every resource has been deployed in your own AWS account. Replace them with screenshots from your own account for final submission.

## Screenshots
The `screenshots/` folder contains ten step-wise console reference images. The red instructional boxes/markups were removed where detected. Do not present reference screenshots as personal deployment proof.
