#################################
# Locals variables
#################################
variable "environment" {
  description = "Environment name (dev, qa, staging, prod.)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = contains(["dev", "qa", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, staging, prod."
  }
}

variable "company_name" {
  description = "Name of the company (used in naming pattern)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.company_name))
    error_message = "Company name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "project_name" {
  description = "Name of the project (used in naming pattern)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

#################################
# Environment configurations using locals
#################################
locals {
  # Scalable configurations per environment
  environment_defaults = {
    dev = {
      instance_type          = "t3.micro"
      monitoring             = false
      termination_protection = false
      root_volume_size       = 30
      instance_count         = 1
    }
    qa = {
      instance_type          = "t3.small"
      monitoring             = true
      termination_protection = false
      root_volume_size       = 40
      instance_count         = 2
    }
    staging = {
      instance_type          = "t3.medium"
      monitoring             = true
      termination_protection = true
      root_volume_size       = 50
      instance_count         = 2
    }
    prod = {
      instance_type          = "t3.large"
      monitoring             = true
      termination_protection = true
      root_volume_size       = 100
      instance_count         = 3
    }
  }

  # Apply defaults per environment
  env_config = local.environment_defaults[var.environment]
}

#################################
# aws_ami variables with optional()
#################################
variable "ami_config" {
  description = "AMI configuration with optional attributes"
  type = object({
    ami_id = optional(string)
    owners = optional(list(string), ["099720109477"]) # Canonical (Ubuntu)
    filters = optional(list(object({
      name   = string
      values = list(string)
      })), [
      {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
      },
      {
        name   = "state"
        values = ["available"]
      }
    ])
  })
  default = {}
}

#################################
# Key Pair with optional()
#################################
variable "key_pair_config" {
  description = "Key pair configuration with optional attributes"
  type = object({
    create_new        = optional(bool, false)
    public_key        = optional(string)
    existing_key_name = optional(string)
    key_name_suffix   = optional(string, "key")
  })
  default = {}

  validation {
    condition = (
      (var.key_pair_config.create_new && var.key_pair_config.public_key != null) ||
      (!var.key_pair_config.create_new && var.key_pair_config.existing_key_name != null)
    )
    error_message = "When create_new=true, public_key is required. When create_new=false, existing_key_name is required."
  }
}

#################################
# Network configuration with optional()
#################################
variable "network_config" {
  description = "Network configuration with optional attributes"
  type = object({
    subnet_ids                  = list(string)
    security_group_ids          = list(string)
    associate_public_ip_address = optional(bool, false)
    eip_count                   = optional(number, 0)
  })

  validation {
    condition     = length(var.network_config.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }

  validation {
    condition     = length(var.network_config.security_group_ids) > 0
    error_message = "At least one security group ID must be provided."
  }

  validation {
    condition     = var.network_config.eip_count >= 0 && var.network_config.eip_count <= 100
    error_message = "EIP count must be between 0 and 100."
  }
}

#################################
# Instance configuration with robust validations
#################################
variable "instance_config" {
  description = "EC2 instance configuration with advanced optional attributes"
  type = object({
    instance_count                       = optional(number)
    instance_type                        = optional(string)
    monitoring                           = optional(bool)
    disable_api_termination              = optional(bool)
    disable_api_stop                     = optional(bool)
    instance_initiated_shutdown_behavior = optional(string, "stop")
    iam_instance_profile_name            = optional(string)
    user_data                            = optional(string)
    user_data_replace_on_change          = optional(bool, false)
  })
  default = {}

  # Robust validation for instance_type
  validation {
    condition     = var.instance_config.instance_type == null || can(regex("^[a-z][0-9][a-z]?(\\.[a-z0-9]+)$", var.instance_config.instance_type))
    error_message = "Instance type must be a valid EC2 instance type format (e.g., t3.micro, m5.large, c5n.xlarge)."
  }

  # Validation for allowed instance families
  validation {
    condition     = var.instance_config.instance_type == null || can(regex("^(t2|t3|t3a|t4g|m5|m5a|m5n|m6i|m6a|m7i|c5|c5a|c5n|c6i|c6a|c7i|r5|r5a|r5n|r6i|r6a|r7i|x1|x1e|z1d|i3|i4i|d3|d3en|h1)\\.", var.instance_config.instance_type))
    error_message = "Instance type must be from supported families: t2, t3, t3a, t4g, m5, m5a, m5n, m6i, m6a, m7i, c5, c5a, c5n, c6i, c6a, c7i, r5, r5a, r5n, r6i, r6a, r7i, x1, x1e, z1d, i3, i4i, d3, d3en, h1."
  }

  validation {
    condition     = var.instance_config.instance_count == null || (var.instance_config.instance_count > 0 && var.instance_config.instance_count <= 100)
    error_message = "Instance count must be between 1 and 100."
  }

  validation {
    condition     = contains(["stop", "terminate"], var.instance_config.instance_initiated_shutdown_behavior)
    error_message = "Instance initiated shutdown behavior must be either 'stop' or 'terminate'."
  }
}

#################################
# Root volume with improved optional()
#################################
variable "root_volume" {
  description = "Root volume configuration with optional attributes and intelligent defaults"
  type = object({
    type                  = optional(string, "gp3")
    size                  = optional(number)
    iops                  = optional(number)
    throughput            = optional(number)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
    delete_on_termination = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], var.root_volume.type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2, sc1, st1."
  }

  validation {
    condition     = var.root_volume.size == null || (var.root_volume.size >= 8 && var.root_volume.size <= 16384)
    error_message = "Root volume size must be between 8 and 16384 GB."
  }

  # IOPS validation based on volume type
  validation {
    condition = (
      var.root_volume.iops == null ||
      (var.root_volume.type == "gp3" && var.root_volume.iops >= 3000 && var.root_volume.iops <= 16000) ||
      (var.root_volume.type == "io1" && var.root_volume.iops >= 100 && var.root_volume.iops <= 64000) ||
      (var.root_volume.type == "io2" && var.root_volume.iops >= 100 && var.root_volume.iops <= 256000) ||
      contains(["gp2", "sc1", "st1"], var.root_volume.type)
    )
    error_message = "IOPS must be compatible with volume type: gp3 (3000-16000), io1 (100-64000), io2 (100-256000)."
  }

  # Throughput validation for gp3
  validation {
    condition = (
      var.root_volume.throughput == null ||
      (var.root_volume.type == "gp3" && var.root_volume.throughput >= 125 && var.root_volume.throughput <= 1000) ||
      var.root_volume.type != "gp3"
    )
    error_message = "Throughput is only valid for gp3 volumes and must be between 125 and 1000 MB/s."
  }
}

#################################
# EBS optimized with map(object())
#################################
variable "ebs_volumes" {
  description = "Map of EBS volumes to create with flexible configuration"
  type = map(object({
    # Basic configuration
    device_name = string
    volume_type = optional(string, "gp3")
    volume_size = number

    # Advanced optional configuration
    iops                  = optional(number)
    throughput            = optional(number)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
    snapshot_id           = optional(string)
    delete_on_termination = optional(bool, true)

    # Multi-attach and other options
    multi_attach_enabled = optional(bool, false)
    availability_zone    = optional(string) # If specified, it's used; if not, taken from instance

    # Attachment configuration  
    instance_indices = optional(list(number), [0]) # Which instances to attach (by index)

    # Volume-specific tags
    tags = optional(map(string), {})
  }))
  default = {}

  # Robust validations for each volume
  validation {
    condition = alltrue([
      for vol_name, vol in var.ebs_volumes : contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], vol.volume_type)
    ])
    error_message = "All EBS volume types must be one of: gp2, gp3, io1, io2, sc1, st1."
  }

  validation {
    condition = alltrue([
      for vol_name, vol in var.ebs_volumes : vol.volume_size >= 1 && vol.volume_size <= 16384
    ])
    error_message = "All EBS volume sizes must be between 1 and 16384 GB."
  }

  validation {
    condition = alltrue([
      for vol_name, vol in var.ebs_volumes : can(regex("^/dev/[a-z]+[0-9]?$", vol.device_name))
    ])
    error_message = "All EBS device names must follow the pattern /dev/xxx or /dev/xxx# (e.g., /dev/sdf, /dev/xvdf1)."
  }

  # IOPS validation by volume type
  validation {
    condition = alltrue([
      for vol_name, vol in var.ebs_volumes : (
        vol.iops == null ||
        (vol.volume_type == "gp3" && vol.iops >= 3000 && vol.iops <= 16000) ||
        (vol.volume_type == "io1" && vol.iops >= 100 && vol.iops <= 64000) ||
        (vol.volume_type == "io2" && vol.iops >= 100 && vol.iops <= 256000) ||
        contains(["gp2", "sc1", "st1"], vol.volume_type)
      )
    ])
    error_message = "IOPS must be compatible with volume type for all volumes: gp3 (3000-16000), io1 (100-64000), io2 (100-256000)."
  }

  # Throughput validation for gp3
  validation {
    condition = alltrue([
      for vol_name, vol in var.ebs_volumes : (
        vol.throughput == null ||
        (vol.volume_type == "gp3" && vol.throughput >= 125 && vol.throughput <= 1000) ||
        vol.volume_type != "gp3"
      )
    ])
    error_message = "Throughput is only valid for gp3 volumes and must be between 125 and 1000 MB/s for all volumes."
  }
}

#################################
# Variables de Tags
#################################

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  type = object({
    instances   = optional(map(string), {})
    volumes     = optional(map(string), {})
    root_volume = optional(map(string), {})
    key_pairs   = optional(map(string), {})
    eips        = optional(map(string), {})
  })
}

#################################
# Tags with improved optional structure
#################################
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for key, value in var.tags : can(regex("^[a-zA-Z0-9_.:/=+\\-@]+$", key))
    ])
    error_message = "All tag keys must contain only alphanumeric characters, spaces, and the following characters: _ . : / = + - @"
  }
}

variable "additional_tags" {
  description = "Additional tags for specific resource types with optional structure"
  type = object({
    instances   = optional(map(string), {})
    volumes     = optional(map(string), {})
    root_volume = optional(map(string), {})
    key_pairs   = optional(map(string), {})
    eips        = optional(map(string), {})
  })
  default = {}
}