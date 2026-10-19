# ── Identity ──────────────────────────────────────────────
variable "environment" {
  description = "Environment: dev | qa | prod"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "organization" {
  description = "Organization name"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.organization))
    error_message = "Organization must contain only lowercase letters, numbers, and hyphens."
  }
}

# ── Instances ─────────────────────────────────────────────
variable "instances" {
  description = "Instance definitions as map"
  type = map(object({
    instance_type = string
    subnet_id     = string

    monitoring                  = optional(bool, false)
    disable_api_termination     = optional(bool, false)
    disable_api_stop            = optional(bool, false)
    iam_instance_profile        = optional(string)
    user_data                   = optional(string)
    user_data_replace_on_change = optional(bool, false)
    eip                         = optional(bool, false)

    ingress_rules = optional(list(object({
      description     = string
      from_port        = number
      to_port          = number
      protocol         = string
      cidr_blocks      = optional(list(string), [])
      security_groups  = optional(list(string), [])
    })))
  }))
  default = {}
}

# ── AMI ───────────────────────────────────────────────────
variable "ami_id" {
  description = "AMI ID. If null, the latest AMI is resolved via ami_owners and ami_filters"
  type        = string
  default     = null
}

variable "ami_owners" {
  description = "List of AMI owners for data source lookup"
  type        = list(string)
  default     = ["099720109477"] # Canonical (Ubuntu)
}

variable "ami_filters" {
  description = "Filters for AMI data source lookup"
  type = list(object({
    name   = string
    values = list(string)
  }))
  default = [
    {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
    },
    {
      name   = "state"
      values = ["available"]
    }
  ]
}

# ── Key Pair ──────────────────────────────────────────────
variable "create_key_pair" {
  description = "Whether to create a new key pair. If false, existing_key_name is required"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key material. Required when create_key_pair = true"
  type        = string
  default     = null
}

variable "key_name" {
  description = "Optional identifier inserted into the key pair name (e.g. 'agentcicd' -> dev-doters-agentcicd-key). Null keeps the default dev-doters-key"
  type        = string
  default     = null
}

variable "existing_key_name" {
  description = "Name of an existing key pair. Required when create_key_pair = false"
  type        = string
  default     = null
}

# ── Network ───────────────────────────────────────────────
variable "vpc_id" {
  description = "VPC ID where the security group is created"
  type        = string
}

variable "create_security_group" {
  description = "Whether the module creates a security group. If false, only security_group_ids are attached"
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "Ingress rules for the security group created by this module"
  type = list(object({
    description     = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string), [])
    security_groups  = optional(list(string), [])
  }))
  default = []
}

variable "security_group_ids" {
  description = "Additional existing security group IDs to attach alongside the module-created one"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address to instances"
  type        = bool
  default     = false
}

# ── Instance ──────────────────────────────────────────────
variable "shutdown_behavior" {
  description = "Instance shutdown behavior: stop | terminate"
  type        = string
  default     = "stop"

  validation {
    condition     = contains(["stop", "terminate"], var.shutdown_behavior)
    error_message = "shutdown_behavior must be 'stop' or 'terminate'."
  }
}

variable "metadata_hop_limit" {
  description = "HTTP PUT response hop limit for IMDSv2 (1-64)"
  type        = number
  default     = 2

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 64
    error_message = "metadata_hop_limit must be between 1 and 64."
  }
}

# ── Root Volume ───────────────────────────────────────────
variable "root_volume" {
  description = "Root volume configuration shared across all instances"
  type = object({
    type       = optional(string, "gp3")
    size       = optional(number, 30)
    iops       = optional(number)
    throughput = optional(number)
    encrypted  = optional(bool, true)
    kms_key_id            = optional(string, "")
    delete_on_termination = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], var.root_volume.type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2, sc1, st1."
  }

  validation {
    condition     = var.root_volume.size >= 8 && var.root_volume.size <= 16384
    error_message = "Root volume size must be between 8 and 16384 GB."
  }

  validation {
    condition = (
      var.root_volume.iops == null ||
      (var.root_volume.type == "gp3" && var.root_volume.iops >= 3000 && var.root_volume.iops <= 16000) ||
      (var.root_volume.type == "io1" && var.root_volume.iops >= 100 && var.root_volume.iops <= 64000) ||
      (var.root_volume.type == "io2" && var.root_volume.iops >= 100 && var.root_volume.iops <= 256000) ||
      contains(["gp2", "sc1", "st1"], var.root_volume.type)
    )
    error_message = "IOPS must match volume type: gp3 (3000-16000), io1 (100-64000), io2 (100-256000)."
  }

  validation {
    condition = (
      var.root_volume.throughput == null ||
      (var.root_volume.type == "gp3" && var.root_volume.throughput >= 125 && var.root_volume.throughput <= 1000) ||
      var.root_volume.type != "gp3"
    )
    error_message = "Throughput is only valid for gp3 volumes and must be between 125 and 1000 MB/s."
  }
}

# ── EBS Volumes ───────────────────────────────────────────
variable "ebs_volumes" {
  description = "Map of additional EBS volumes. Each volume references an instance by its key name"
  type = map(object({
    instance_key = string
    device_name  = string
    size         = number
    type         = optional(string, "gp3")
    iops         = optional(number)
    throughput   = optional(number)
    encrypted    = optional(bool, true)
    kms_key_id           = optional(string, "")
    snapshot_id          = optional(string, "")
    multi_attach_enabled = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ebs_volumes : contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], v.type)
    ])
    error_message = "All EBS volume types must be one of: gp2, gp3, io1, io2, sc1, st1."
  }

  validation {
    condition = alltrue([
      for k, v in var.ebs_volumes : v.size >= 1 && v.size <= 16384
    ])
    error_message = "All EBS volume sizes must be between 1 and 16384 GB."
  }

  validation {
    condition = alltrue([
      for k, v in var.ebs_volumes : can(regex("^/dev/[a-z]+[0-9]?$", v.device_name))
    ])
    error_message = "All device names must follow the pattern /dev/sdX or /dev/xvdX (e.g., /dev/sdf)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ebs_volumes : (
        v.iops == null ||
        (v.type == "gp3" && v.iops >= 3000 && v.iops <= 16000) ||
        (v.type == "io1" && v.iops >= 100 && v.iops <= 64000) ||
        (v.type == "io2" && v.iops >= 100 && v.iops <= 256000) ||
        contains(["gp2", "sc1", "st1"], v.type)
      )
    ])
    error_message = "IOPS must match volume type: gp3 (3000-16000), io1 (100-64000), io2 (100-256000)."
  }
}