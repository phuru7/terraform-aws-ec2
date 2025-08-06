locals {
  name_pattern = "${var.environment}-${var.company_name}-${var.project_name}"
}


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

resource "aws_key_pair" "this" {
  count      = var.key_pair_config.create_new ? 1 : 0
  key_name   = "${local.name_pattern}-key"
  public_key = var.key_pair_config.public_key

  tags = merge(
    var.tags,
    var.additional_tags.key_pairs,
    {
      Name = "${local.name_pattern}-key"
    }
  )
}

resource "aws_eip" "this" {
  count    = min(var.eip_count, var.instance_count)
  instance = aws_instance.this[count.index].id
  domain   = "vpc"

  tags = merge(
    var.tags,
    var.additional_tags.eips,
    {
      Name = "${local.name_pattern}-${count.index + 1}-eip"
    }
  )
  depends_on = [aws_instance.this]
}

resource "aws_ebs_volume" "this" {
  count             = length(var.ebs_block_devices)
  availability_zone = aws_instance.this[count.index].availability_zone
  size              = var.ebs_block_devices[count.index].volume_size
  type              = var.ebs_block_devices[count.index].volume_type
  iops              = var.ebs_block_devices[count.index].iops
  throughput        = var.ebs_block_devices[count.index].throughput
  encrypted         = var.ebs_block_devices[count.index].encrypted
  kms_key_id        = var.ebs_block_devices[count.index].kms_key_id
  snapshot_id       = var.ebs_block_devices[count.index].snapshot_id

  tags = merge(
    var.tags,
    var.ebs_block_devices[count.index].tags,
    {
      Name = "${local.name_pattern}-${count.index + 1}-${var.ebs_block_devices[count.index].custom_name}-disk"
    }
  )
}

resource "aws_volume_attachment" "this" {
  count       = length(var.ebs_block_devices)
  device_name = var.ebs_block_devices[count.index].device_name
  volume_id   = aws_ebs_volume.this[count.index].id
  instance_id = aws_instance.this[count.index].id
}

resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.this[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_pair_config.create_new ? aws_key_pair.this[0].key_name : var.key_pair_config.existing_key_name

  root_block_device {
    volume_type           = var.root_volume.type
    volume_size           = var.root_volume.size
    iops                  = var.root_volume.iops
    throughput            = var.root_volume.throughput
    encrypted             = var.root_volume.encrypted
    kms_key_id            = var.root_volume.kms_key_id
    delete_on_termination = var.root_volume.delete_on_termination
  }

  volume_tags = merge(
    var.tags,
    var.additional_tags.root_volume,
    {
      Name = "${local.name_pattern}-${count.index + 1}-root-disk"
    }
  )

  monitoring                            = var.monitoring
  disable_api_termination               = var.disable_api_termination
  disable_api_stop                      = var.disable_api_stop
  instance_initiated_shutdown_behavior  = var.instance_initiated_shutdown_behavior
  
  iam_instance_profile                  = var.iam_instance_profile_name
  user_data                             = var.user_data
  user_data_replace_on_change           = var.user_data_replace_on_change

  tags = merge(
    var.tags,
    var.additional_tags.instances,
    {
      Name = "${local.name_pattern}-${count.index + 1}"
    }
  )

  lifecycle {
    ignore_changes = [
      tags["LastModified"],
    ]
  }
}
