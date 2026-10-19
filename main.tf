# ── Locals ────────────────────────────────────────────────
locals {
  prefix = "${var.environment}-${var.organization}"
}

# ── Validations ───────────────────────────────────────────
check "security_group_source" {
  assert {
    condition     = var.create_security_group || length(var.security_group_ids) > 0
    error_message = "When create_security_group = false, at least one security_group_ids entry is required."
  }
}

# ── AMI ───────────────────────────────────────────────────
data "aws_ami" "this" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = var.ami_owners

  dynamic "filter" {
    for_each = var.ami_filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

# ── Security Group ────────────────────────────────────────
resource "aws_security_group" "this" {
  for_each = var.create_security_group ? var.instances : {}

  name        = "${local.prefix}-${each.key}-sg"
  description = "Security group for ${local.prefix}-${each.key}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = coalesce(each.value.ingress_rules, var.ingress_rules)
    content {
      description     = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      security_groups  = ingress.value.security_groups
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-${each.key}-sg"
  }
}

# ── Key Pair ──────────────────────────────────────────────
resource "aws_key_pair" "this" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name != null ? "${local.prefix}-${var.key_name}-key" : "${local.prefix}-key"
  public_key = var.public_key

  tags = {
    Name = var.key_name != null ? "${local.prefix}-${var.key_name}-key" : "${local.prefix}-key"
  }
}

# ── EC2 Instances ─────────────────────────────────────────
resource "aws_instance" "this" {
  for_each = var.instances

  ami = var.ami_id != null ? var.ami_id : data.aws_ami.this[0].id

  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id

  vpc_security_group_ids = compact(concat(
    var.create_security_group ? [aws_security_group.this[each.key].id] : [],
    var.security_group_ids
  ))

  associate_public_ip_address = var.associate_public_ip_address

  key_name = var.create_key_pair ? aws_key_pair.this[0].key_name : var.existing_key_name

  root_block_device {
    volume_type           = var.root_volume.type
    volume_size           = var.root_volume.size
    iops                  = var.root_volume.iops
    throughput            = var.root_volume.throughput
    encrypted             = var.root_volume.encrypted
    kms_key_id            = var.root_volume.kms_key_id != "" ? var.root_volume.kms_key_id : null
    delete_on_termination = var.root_volume.delete_on_termination
  }

  monitoring                           = each.value.monitoring
  disable_api_termination              = each.value.disable_api_termination
  disable_api_stop                     = each.value.disable_api_stop
  instance_initiated_shutdown_behavior = var.shutdown_behavior

  iam_instance_profile        = each.value.iam_instance_profile
  user_data                   = each.value.user_data
  user_data_replace_on_change = each.value.user_data_replace_on_change

  # ── IMDSv2 enforced — not configurable ────────────────────
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.metadata_hop_limit
    instance_metadata_tags      = "disabled"
  }

  lifecycle {
    ignore_changes = [tags["LastModified"], ami]

    precondition {
      condition     = var.create_key_pair ? var.public_key != null : var.existing_key_name != null
      error_message = "When create_key_pair=true, public_key is required. When false, existing_key_name is required."
    }

    precondition {
      condition     = var.environment == "prod" ? each.value.disable_api_termination == true : true
      error_message = "disable_api_termination must be true for instance '${each.key}' in prod environment."
    }

    precondition {
      condition     = var.environment == "prod" ? each.value.monitoring == true : true
      error_message = "monitoring must be enabled for instance '${each.key}' in prod environment."
    }

    postcondition {
      condition     = self.instance_state == "running" || self.instance_state == "pending"
      error_message = "Instance '${each.key}' must be in running or pending state after creation."
    }
  }

  tags = {
    Name = "${local.prefix}-${each.key}-ec2"
  }

  volume_tags = {
    Name = "${local.prefix}-${each.key}-root"
  }
}

# ── EBS Volumes ───────────────────────────────────────────
resource "aws_ebs_volume" "this" {
  for_each = var.ebs_volumes

  availability_zone = aws_instance.this[each.value.instance_key].availability_zone

  size                 = each.value.size
  type                 = each.value.type
  iops                 = each.value.iops
  throughput           = each.value.throughput
  encrypted            = each.value.encrypted
  kms_key_id           = each.value.kms_key_id != "" ? each.value.kms_key_id : null
  snapshot_id          = each.value.snapshot_id != "" ? each.value.snapshot_id : null
  multi_attach_enabled = each.value.multi_attach_enabled

  tags = {
    Name = "${local.prefix}-${each.key}-volume"
  }
}

resource "aws_volume_attachment" "this" {
  for_each = var.ebs_volumes

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value.instance_key].id
}

# ── Elastic IPs ───────────────────────────────────────────
resource "aws_eip" "this" {
  for_each = { for k, v in var.instances : k => v if v.eip }

  instance = aws_instance.this[each.key].id
  domain   = "vpc"

  tags = {
    Name = "${local.prefix}-${each.key}-eip"
  }
}