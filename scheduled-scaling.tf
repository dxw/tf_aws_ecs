locals {
  autoscaling_time_based_max = toset(var.autoscaling_time_based_max)
  autoscaling_time_based_min = toset(var.autoscaling_time_based_min)
  autoscaling_time_based_custom = {
    for custom in toset(var.autoscaling_time_based_custom) : "${custom["min"]}-${custom["max"]} ${custom["cron"]}" => custom
  }
}

resource "aws_autoscaling_schedule" "ecs_infrastructure_time_based_max" {
  for_each = local.autoscaling_time_based_max

  autoscaling_group_name = aws_autoscaling_group.ecs.name
  scheduled_action_name  = "asg-${aws_launch_template.ecs.name}-schedule-max ${each.value}"
  time_zone              = "Europe/London"
  desired_capacity       = var.max_servers
  min_size               = -1
  max_size               = -1
  recurrence             = each.value
}

resource "aws_autoscaling_schedule" "ecs_infrastructure_time_based_min" {
  for_each = local.autoscaling_time_based_min

  autoscaling_group_name = aws_autoscaling_group.ecs.name
  scheduled_action_name  = "asg-${aws_launch_template.ecs.name}-schedule-min ${each.value}"
  time_zone              = "Europe/London"
  desired_capacity       = var.min_servers
  min_size               = -1
  max_size               = -1
  recurrence             = each.value
}

resource "aws_autoscaling_schedule" "ecs_infrastructure_time_based_custom" {
  for_each = local.autoscaling_time_based_custom

  autoscaling_group_name = aws_autoscaling_group.ecs.name
  scheduled_action_name  = "asg-${aws_launch_template.ecs.name}-schedule-custom ${each.value["cron"]}  ${each.value["min"]}-${each.value["max"]}"
  desired_capacity       = each.value["min"]
  min_size               = each.value["min"]
  max_size               = each.value["max"]
  recurrence             = each.value["cron"]
}
