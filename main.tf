locals {
  name_pattern = "${var.environment}-${var.company_name}-${var.project_name}"
}


#################################
# Data Sources
#################################
data "aws_ami" "this" {
  count       = var.ami_config.ami_id == null ? 1 : 0
  most_recent = true
  owners      = var.ami_config.owners

  dynamic "filter" {
    for_each = var.ami_config.filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

#################################
# Key Pair
#################################
resource "aws_key_pair" "this" {
  count      = var.key_pair_config.create_new ? 1 : 0
  key_name   = "${local.name_pattern}-${var.key_pair_config.key_name_suffix}"
  public_key = var.key_pair_config.public_key

  tags = merge(
    var.tags,
    var.additional_tags.key_pairs,
    {
      Name        = "${local.name_pattern}-${var.key_pair_config.key_name_suffix}"
      Environment = var.environment
      Company     = var.company_name
      Project     = var.project_name
    }
  )
}

#################################
# EBS 
#################################
resource "aws_ebs_volume" "this" {
  for_each = {
    for attachment in local.ebs_volume_attachments : 
    "${attachment.volume_name}-${attachment.instance_index}" => attachment
  }

  availability_zone = coalesce(
    each.value.volume_config.availability_zone,
    aws_instance.this[each.value.instance_index].availability_zone
  )
  
  size              = each.value.volume_config.volume_size
  type              = each.value.volume_config.volume_type
  iops              = each.value.volume_config.iops
  throughput        = each.value.volume_config.throughput
  encrypted         = each.value.volume_config.encrypted
  kms_key_id        = each.value.volume_config.kms_key_id
  snapshot_id       = each.value.volume_config.snapshot_id
  multi_attach_enabled = each.value.volume_config.multi_attach_enabled

  tags = merge(
    var.tags,
    var.additional_tags.volumes,
    each.value.volume_config.tags,
    {
      Name        = "${local.name_pattern}-${each.value.instance_index + 1}-${each.value.volume_name}"
      Environment = var.environment
      Company     = var.company_name
      Project     = var.project_name
      VolumeType  = each.value.volume_config.volume_type
      Instance    = "${local.name_pattern}-${each.value.instance_index + 1}"
    }
  )
}

resource "aws_volume_attachment" "this" {
  for_each = {
    for attachment in local.ebs_volume_attachments : 
    "${attachment.volume_name}-${attachment.instance_index}" => attachment
  }

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value.instance_index].id
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

  monitoring                           = var.monitoring
  disable_api_termination              = var.disable_api_termination
  disable_api_stop                     = var.disable_api_stop
  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior

  iam_instance_profile        = var.iam_instance_profile_name
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

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
