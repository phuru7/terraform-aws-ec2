locals {
  name_pattern = "${var.environment}-${var.company_name}-${var.project_name}"
  
  # Resolved configuration with environment defaults
  resolved_instance_count = coalesce(
    var.instance_config.instance_count,
    local.env_config.instance_count
  )
  
  resolved_instance_type = coalesce(
    var.instance_config.instance_type,
    local.env_config.instance_type
  )
  
  resolved_monitoring = coalesce(
    var.instance_config.monitoring,
    local.env_config.monitoring
  )
  
  resolved_disable_api_termination = coalesce(
    var.instance_config.disable_api_termination,
    local.env_config.termination_protection
  )
  
  resolved_disable_api_stop = coalesce(
    var.instance_config.disable_api_stop,
    false
  )
  
  resolved_shutdown_behavior = coalesce(
    var.instance_config.instance_initiated_shutdown_behavior,
    "stop"
  )
  
  resolved_root_volume_size = coalesce(
    var.root_volume.size,
    local.env_config.root_volume_size
  )
  
  # Lista expandida de volúmenes EBS por instancia
  ebs_volume_attachments = flatten([
    for vol_name, vol_config in var.ebs_volumes : [
      for instance_idx in vol_config.instance_indices : {
        volume_name    = vol_name
        instance_index = instance_idx
        device_name    = vol_config.device_name
        volume_config  = vol_config
      }
    ]
  ])
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

#################################
# EC2 Instances
#################################

resource "aws_instance" "this" {
  count = local.resolved_instance_count
  
  ami           = var.ami_config.ami_id != null ? var.ami_config.ami_id : data.aws_ami.this[0].id
  instance_type = local.resolved_instance_type
  subnet_id     = var.network_config.subnet_ids[count.index % length(var.network_config.subnet_ids)]
  
  vpc_security_group_ids      = var.network_config.security_group_ids
  associate_public_ip_address = var.network_config.associate_public_ip_address
  
  key_name = var.key_pair_config.create_new ? aws_key_pair.this[0].key_name : var.key_pair_config.existing_key_name

  root_block_device {
    volume_type           = var.root_volume.type
    volume_size           = local.resolved_root_volume_size
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
      Name        = "${local.name_pattern}-${count.index + 1}-root"
      Environment = var.environment
      Company     = var.company_name
      Project     = var.project_name
      VolumeType  = var.root_volume.type
      Instance    = "${local.name_pattern}-${count.index + 1}"
    }
  )

  monitoring                           = local.resolved_monitoring
  disable_api_termination              = local.resolved_disable_api_termination
  disable_api_stop                     = local.resolved_disable_api_stop
  instance_initiated_shutdown_behavior = local.resolved_shutdown_behavior
  
  iam_instance_profile        = var.instance_config.iam_instance_profile_name
  user_data                   = var.instance_config.user_data
  user_data_replace_on_change = var.instance_config.user_data_replace_on_change

  tags = merge(
    var.tags,
    var.additional_tags.instances,
    {
      Name         = "${local.name_pattern}-${count.index + 1}"
      Environment  = var.environment
      Company      = var.company_name
      Project      = var.project_name
      InstanceType = local.resolved_instance_type
      Index        = count.index + 1
    }
  )

  lifecycle {
    ignore_changes = [
      tags["LastModified"],
    ]
    
    # Preconditions to validate configuration
    precondition {
      condition = length(var.network_config.subnet_ids) > 0
      error_message = "At least one subnet must be provided in network_config.subnet_ids."
    }
    
    precondition {
      condition = length(var.network_config.security_group_ids) > 0
      error_message = "At least one security group must be provided in network_config.security_group_ids."
    }
    
    # Key pair configuration validation 
    precondition {
      condition = (
        (var.key_pair_config.create_new && var.key_pair_config.public_key != null) ||
        (!var.key_pair_config.create_new && var.key_pair_config.existing_key_name != null)
      )
      error_message = "Key pair configuration is invalid. When create_new=true, public_key is required. When create_new=false, existing_key_name is required."
    }
    
    # Postcondition to validate created instance
    postcondition {
      condition = self.instance_state == "running" || self.instance_state == "pending"
      error_message = "Instance must be in running or pending state after creation."
    }
  }
}

#################################
# Elastic IPs
#################################
resource "aws_eip" "this" {
  count    = min(var.network_config.eip_count, local.resolved_instance_count)
  instance = aws_instance.this[count.index].id
  domain   = "vpc"

  tags = merge(
    var.tags,
    var.additional_tags.eips,
    {
      Name        = "${local.name_pattern}-${count.index + 1}-eip"
      Environment = var.environment
      Company     = var.company_name
      Project     = var.project_name
      Instance    = "${local.name_pattern}-${count.index + 1}"
    }
  )
  
  depends_on = [aws_instance.this]
}