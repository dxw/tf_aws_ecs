data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [local.ami]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_launch_template" "ecs" {
  name = "ecs-${var.name}"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 40
      encrypted             = true
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = var.ebs_block_device

    ebs {
      encrypted             = true
      volume_size           = var.docker_storage_size
      volume_type           = var.ebs_volume_type
      delete_on_termination = true
    }
  }

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = concat(tolist([aws_security_group.ecs.id]), var.security_group_ids)
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_profile.name
  }

  monitoring {
    enabled = true
  }

  dynamic "instance_market_options" {
    for_each = var.spot_bid_price == "" ? [] : [1]
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "terminate"
        max_price                      = var.spot_bid_price
        spot_instance_type             = "one-time"
      }
    }
  }

  disable_api_termination              = false
  ebs_optimized                        = true
  image_id                             = data.aws_ami.ecs_ami.id
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = var.instance_type
  user_data = base64encode(coalesce(var.user_data, templatefile(
    "${path.module}/templates/user_data.tpl",
    {
      additional_user_data_script = var.additional_user_data_script
      cluster_name                = aws_ecs_cluster.cluster.name
      docker_storage_device_name  = var.ebs_block_device
      docker_storage_size         = var.docker_storage_size
      dockerhub_token             = var.dockerhub_token
      dockerhub_email             = var.dockerhub_email
    }
  )))
}

locals {
  ecs_asg_tags_init = [{
    key                 = "Name"
    value               = "${var.name} ${var.tagName}"
    propagate_at_launch = true
  }]

  ecs_asg_tags = concat(local.ecs_asg_tags_init, var.extra_tags)
}

resource "aws_autoscaling_group" "ecs" {
  name_prefix         = "asg-${aws_launch_template.ecs.name}-"
  vpc_zone_identifier = var.subnet_id

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  min_size              = var.min_servers
  max_size              = var.max_servers
  desired_capacity      = var.servers
  termination_policies  = ["OldestLaunchConfiguration", "ClosestToNextInstanceHour", "Default"]
  max_instance_lifetime = var.max_instance_lifetime
  load_balancers        = var.load_balancers
  enabled_metrics       = var.enabled_metrics

  tags = local.ecs_asg_tags

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
    triggers = ["tag"]
  }

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    delete = "${var.heartbeat_timeout + var.asg_delete_extra_timeout}s"
  }
}

resource "aws_security_group" "ecs" {
  name        = "ecs-sg-${var.name}"
  description = "Container Instance Allowed Ports"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_egress_cidr_blocks
  }

  tags = {
    Name = "ecs-sg-${var.name}"
  }
}

# Make this a var that an get passed in?
resource "aws_ecs_cluster" "cluster" {
  name = var.name
}
