provider "aws" {
  region = var.region
}

data "aws_route53_zone" "main" {
  name = var.domainName
}

locals {
  user_data = <<EOF
#!/bin/bash
sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
EOF
}

# vpc

module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = var.name
  cidr            = "10.0.0.0/16"
  azs             = var.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false

  tags = var.tags
  vpc_tags = {
    Name = var.name
  }
}

#asg

module "autoscaling_instances" {
  source = "./modules/asg"

  name            = var.name
  ami             = "ami-0823c236601fef765"
  instance_type   = "t1.micro"
  vpc_id          = module.vpc.vpc_id
  security_groups = aws_security_group.ec2-http.id
  alb             = aws_alb_target_group.foo.arn

  desired_capacity = 3
  max_size         = 6
  min_size         = 3
  subnets          = module.vpc.private_subnets
  user_data        = base64encode(local.user_data)
}

resource "aws_security_group" "ec2-http" {
  name   = "Allow HTTP from ALB"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "Allow HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-https.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP from ALB"
  }
}

# alb

resource "aws_acm_certificate" "cert" {
  domain_name       = var.domainName
  validation_method = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb-https" {
  name   = "Allow in bound HTTPS"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  tags = {
    Name = "Allow in bound HTTPS"
  }
}

resource "aws_lb" "alb" {
  name_prefix        = var.name
  load_balancer_type = "application"
  internal           = false
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb-https.id]

  tags = {
    Environment = "production"
  }

  depends_on = [
    aws_security_group.alb-https
  ]
}


resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = ""
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.foo.arn
  }

  depends_on = [
    aws_alb_target_group.foo,
    aws_acm_certificate.cert
  ]
}

resource "aws_alb_target_group" "foo" {
  name_prefix = var.name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id

  depends_on = [
    aws_lb.alb
  ]

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_route53_record" "foo" {
  name    = "www.${var.domainName}"
  type    = "A"
  zone_id = data.aws_route53_zone.main.id

  alias {
    evaluate_target_health = false
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
  }
}
