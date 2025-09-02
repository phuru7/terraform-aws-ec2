variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "demo-app"
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  default     = "dev"
}

variable "company_name" {
  description = "Company name"
  type        = string
  default     = "acme"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_config" {
  description = "Key pair configuration"
  type = object({
    create_new        = optional(bool, false)
    public_key        = optional(string)
    existing_key_name = optional(string)
  })
  default = {
    create_new        = false
    existing_key_name = "my-existing-key"
  }
}

variable "associate_public_ip_address" {
  description = "Associate public IP address"
  type        = bool
  default     = true
}

variable "root_volume" {
  description = "Root volume configuration"
  type = object({
    type                  = optional(string, "gp3")
    size                  = optional(number, 20)
    encrypted             = optional(bool, true)
    delete_on_termination = optional(bool, true)
  })
  default = {
    type                  = "gp3"
    size                  = 20
    encrypted             = true
    delete_on_termination = true
  }
}

variable "owner" {
  description = "Owner name for tagging"
  type        = string
  default     = "DevOps-Team"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Purpose = "Demo"
    Team    = "DevOps"
  }
}