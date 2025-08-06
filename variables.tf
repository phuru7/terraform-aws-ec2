#################################
# Locals variables
#################################
variable "project_name" {
  description = "Name of the project (used in naming pattern)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, qa, prod, etc.)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "company_name" {
  description = "Name of the company (used in naming pattern)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.company_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

#################################
# aws_ami variables
#################################
variable "ami_id" {
  description = "AMI ID to use for instances. If null, will use latest AMI based on filters"
  type        = string
  default     = null
}

variable "ami_owners" {
  description = "List of AMI owners to limit search. Used when ami_id is null"
  type        = list(string)
  default     = ["099720109477"] # Canonical (Ubuntu)
}

variable "ami_filters" {
  description = "List of filters to find AMI. Used when ami_id is null"
  type = list(object({
    name   = string
    values = list(string)
  }))
  default = [
    {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    },
    {
      name   = "state"
      values = ["available"]
    }
  ]
}

#################################
# Key Pair variables
#################################
variable "key_pair_config" {
  description = "Key pair configuration"
  type = object({
    create_new        = optional(bool, false)
    public_key        = optional(string)
    existing_key_name = optional(string)
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
# aws_eip variables
#################################
variable "eip_count" {
  description = "Number of Elastic IPs to create (0 to instance_count). Set to 0 for no EIPs"
  type        = number
  default     = 0

  validation {
    condition     = var.eip_count >= 0 && var.eip_count <= 100
    error_message = "EIP count must be between 0 and 100."
  }
}

variable "associate_public_ip_address" {
  description = "Associate public IP address to instances"
  type        = bool
  default     = false
}

#################################
# instance variables
#################################

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 100
    error_message = "Instance count must be between 1 and 100."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type (e.g., t3.micro, m5.large)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs where instances will be created. Instances will be distributed across subnets"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to assign to the instances"
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group ID must be provided."
  }
}

variable "root_volume" {
  description = "Root volume configuration"
  type = object({
    type                  = optional(string, "gp3")
    size                  = optional(number, 20)
    iops                  = optional(number)
    throughput            = optional(number)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
    delete_on_termination = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume.type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }

  validation {
    condition     = var.root_volume.size >= 8 && var.root_volume.size <= 50
    error_message = "Root volume size must be between 8 and 50 GB."
  }
}

variable "ebs_block_devices" {
  description = "Additional EBS block devices to attach to instances"
  type = list(object({
    device_name           = string
    custom_name           = string 
    volume_type           = string
    volume_size           = number
    iops                  = optional(number)
    throughput            = optional(number)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
    snapshot_id           = optional(string)
    delete_on_termination = optional(bool, true)
    tags                  = optional(map(string), {})
  }))
  default = []
}

variable "monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = false
}

variable "disable_api_termination" {
  description = "Enable EC2 instance termination protection"
  type        = bool
  default     = false
}

variable "disable_api_stop" {
  description = "Enable EC2 instance stop protection"
  type        = bool
  default     = false
}

variable "instance_initiated_shutdown_behavior" {
  description = "Shutdown behavior for the instance"
  type        = string
  default     = "stop"

  validation {
    condition     = contains(["stop", "terminate"], var.instance_initiated_shutdown_behavior)
    error_message = "Instance initiated shutdown behavior must be either 'stop' or 'terminate'."
  }
}

variable "iam_instance_profile_name" {
  description = "Name of IAM instance profile to attach to instances"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script for instances (will auto-detect if base64 encoded)"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Replace instance if user data changes"
  type        = bool
  default     = false
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