locals {
  ami = var.ami != "" ? "${var.ami}${var.ami_version}" : "al2023-ami-ecs-hvm-${var.ami_version}"
}
