resource "aws_launch_template" "main" {
  name_prefix   = var.name
  image_id      = var.ami
  instance_type = var.instance_type
  user_data     = var.user_data

  vpc_security_group_ids = [
    var.security_groups
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  desired_capacity = var.desired_capacity
  max_size         = var.max_size
  min_size         = var.min_size

  vpc_zone_identifier = var.subnets

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      instance_warmup        = 10
      min_healthy_percentage = 90
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.main.id
  alb_target_group_arn   = var.alb
}