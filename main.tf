terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.50.0"
    }
  }
}

# Provider: Region & Permission to connect with AWS Account through IAM
provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIATQODVZKOTGNX2TV2"
  secret_key = "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"
}

# Resource: Security Group to be attached with EC2 & LoadBalancer
resource "aws_security_group" "terra-sg" {
  name        = "terra-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-0ed6e510ad3a83ffb"

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "terra-sg"
  }
}

# Resource: Create the EC2 with UserData Script
resource "aws_instance" "terra-ec2" {
  ami                    = "ami-0d81306eddc614a45"
  instance_type          = "t2.micro"
  key_name               = "Mithran"         # Change the Key Name
  vpc_security_group_ids = [aws_security_group.terra-sg.id]
  user_data = <<EOF
  #! /bin/bash
  sudo yum update -y
  sudo yum install -y httpd
  sudo systemctl enable httpd
  sudo service httpd start  
  echo "<h1>Welcome to GreensTechnology ! AWS Infra created using Terraform in ap-south-1 Region</h1>" | sudo tee /var/www/html/index.html
  EOF
  tags = {
    Name = "terra-ec2"
  }
}

# RUN: Terraform plan
# RUN: Terraform apply

# Resource: Create the Target Group
resource "aws_lb_target_group" "my-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "vpc-0ed6e510ad3a83ffb"
}

# Resource: Attach the Target Group with the Instance
resource "aws_lb_target_group_attachment" "my-alb-target-group-attachment1" {
  target_group_arn = aws_lb_target_group.my-target-group.arn
  target_id        = aws_instance.terra-ec2.id
  port             = 80
}

# RUN: Terraform plan
# RUN: Terraform apply

# Resource: Create the Application Load Balancer
resource "aws_lb" "my-aws-alb" {
  name     = "my-test-alb"
  internal = false

  security_groups = [
    aws_security_group.terra-sg.id,
  ]

  subnets = [
    "subnet-0ed4ab2803f46a0e9",
    "subnet-060d2a2949ef1a525",
    "subnet-0a5dfc12b0cd949da"
  ]

  tags = {
    Name = "my-test-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

# Resource: Map the Target Group with the ALB Listener
resource "aws_lb_listener" "my-test-alb-listner" {
  load_balancer_arn = "${aws_lb.my-aws-alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.my-target-group.arn}"
  }
}

# RUN: Terraform plan
# RUN: Terraform apply

# Resource: Create Public Hosted Zone
resource "aws_route53_zone" "example" {
  name     = "cloudgreens.in"
}

# Resource: Create Alias Record for ALB
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.example.zone_id
  name    = "cloudgreens.in"
  type    = "A"

  alias {
    name                   = aws_lb.my-aws-alb.dns_name
    zone_id                = aws_lb.my-aws-alb.zone_id
    evaluate_target_health = false
  }
}

# RUN: Terraform plan
# RUN: Terraform apply