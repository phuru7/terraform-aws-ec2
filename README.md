# terraform-aws-ec2

Terraform module for creating EC2 instances with environment-based configuration, flexible EBS volumes, elastic IPs, and automatic resource management.

## Features

- **Environment-based configuration**: Predefined values for `dev`, `qa`, `staging`, `prod`
- **Automatic distribution**: Instances distributed across multiple subnets
- **Flexible EBS volumes**: Granular configuration with robust validations
- **Elastic IPs**: Optional automatic assignment
- **Key pairs**: Create new or use existing
- **Organized tags**: Tagging system by resource type
- **Advanced validations**: Configuration verification before deployment

## Architecture

```
Environment → Instance Config → EC2 Instances
    ↓              ↓               ↓
Defaults    →  EBS Volumes  →  Auto Distribution
    ↓              ↓               ↓
Tags        →  Elastic IPs  →  Across Subnets
```

## Requirements

- Terraform ≥ 1.1
- AWS Provider ~> 6.0
- Configured VPC and subnets
- Existing security groups

## Basic Usage

```hcl
module "app_servers" {
  source = "./terraform-aws-ec2"
  
  # Base configuration
  environment    = "prod"
  company_name   = "acme"
  project_name   = "webapp"
  
  # Network
  network_config = {
    subnet_ids         = ["subnet-12345", "subnet-67890"]
    security_group_ids = ["sg-abcdef"]
    eip_count          = 2
  }
  
  # Existing key pair
  key_pair_config = {
    create_new        = false
    existing_key_name = "my-existing-key"
  }
  
  tags = {
    Owner = "DevOps"
    Cost  = "Engineering"
  }
}
```

## Advanced Usage

```hcl
module "database_servers" {
  source = "./terraform-aws-ec2"
  
  environment    = "prod"
  company_name   = "acme"
  project_name   = "database"
  
  # Override environment defaults
  instance_config = {
    instance_count  = 3
    instance_type   = "r6i.xlarge"
    monitoring      = true
  }
  
  # Custom root volume configuration
  root_volume = {
    type = "gp3"
    size = 200
    iops = 10000
  }
  
  # Additional EBS volumes
  ebs_volumes = {
    data = {
      device_name      = "/dev/sdf"
      volume_size      = 500
      volume_type      = "gp3"
      instance_indices = [0, 1, 2]
      tags = {
        Purpose = "Database Storage"
      }
    }
    logs = {
      device_name      = "/dev/sdg"
      volume_size      = 100
      instance_indices = [0, 1]
    }
  }
  
  network_config = {
    subnet_ids                  = ["subnet-db1", "subnet-db2", "subnet-db3"]
    security_group_ids          = ["sg-database"]
    associate_public_ip_address = false
    eip_count                   = 0
  }
  
  tags = {
    Environment = "production"
    Service     = "database"
    Backup      = "required"
  }
}
```

## Environment Configurations

The module automatically applies optimized configurations per environment:

| Environment | Instance Type | Monitoring | Termination Protection | Root Volume | Instance Count |
|-------------|---------------|------------|----------------------|-------------|----------------|
| `dev`       | t3.micro      | false      | false                | 30 GB       | 1              |
| `qa`        | t3.small      | true       | false                | 40 GB       | 2              |
| `staging`   | t3.medium     | true       | true                 | 50 GB       | 2              |
| `prod`      | t3.large      | true       | true                 | 100 GB      | 3              |

## Main Variables

### Required
```hcl
environment    = "prod"           # dev, qa, staging, prod
company_name   = "acme"           # Company name (lowercase)
project_name   = "webapp"         # Project name (lowercase)

network_config = {
  subnet_ids         = ["subnet-xxx"]    # Minimum 1 subnet
  security_group_ids = ["sg-xxx"]        # Minimum 1 security group
}
```

### Main Optional
```hcl
instance_config = {
  instance_count  = 2              # Override environment default
  instance_type   = "t3.medium"    # Override environment default
  monitoring      = true           # Override environment default
}

ami_config = {
  ami_id = "ami-12345"            # If not specified, uses Ubuntu 24.04 LTS
}

ebs_volumes = {
  volume_name = {
    device_name = "/dev/sdf"
    volume_size = 100
  }
}
```

## Useful Outputs

```hcl
# SSH connection information
output "ssh_commands" {
  value = [
    for conn in module.app_servers.connection_info :
    "ssh -i ~/.ssh/${conn.connection.key_name}.pem ${conn.connection.user}@${conn.host}"
  ]
}

# IPs for load balancer
output "instance_ips" {
  value = module.app_servers.network_info.instances_network.private_ips
}

# Complete information for Ansible
output "ansible_inventory" {
  value = module.app_servers.connection_info
}
```

## Examples

### Web Application (3-Tier)
```hcl
# Frontend
module "frontend" {
  source = "./terraform-aws-ec2"
  
  environment  = "prod"
  company_name = "acme"
  project_name = "frontend"
  
  network_config = {
    subnet_ids         = var.public_subnet_ids
    security_group_ids = [aws_security_group.web.id]
    eip_count          = 2
  }
}

# Backend
module "backend" {
  source = "./terraform-aws-ec2"
  
  environment  = "prod"
  company_name = "acme"
  project_name = "backend"
  
  instance_config = {
    instance_type = "c6i.large"
  }
  
  network_config = {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.app.id]
  }
}
```

### Development with data volumes
```hcl
module "dev_environment" {
  source = "./terraform-aws-ec2"
  
  environment  = "dev"
  company_name = "acme"
  project_name = "development"
  
  ebs_volumes = {
    docker = {
      device_name = "/dev/sdf"
      volume_size = 50
      tags = {
        Purpose = "Docker Storage"
      }
    }
  }
  
  key_pair_config = {
    create_new = true
    public_key = file("~/.ssh/dev-key.pub")
  }
}
```

## Naming Pattern

All resources follow the pattern: `{environment}-{company_name}-{project_name}`

**Examples:**
- Instance: `prod-acme-webapp-1`
- EBS Volume: `prod-acme-webapp-1-data`
- Key Pair: `prod-acme-webapp-key`
- EIP: `prod-acme-webapp-1-eip`

## Validations

The module includes automatic validations for:
- Valid EC2 instance types
- Volume configurations by type (IOPS, throughput)
- Device name formats
- Volume size ranges
- Key pair configuration
- Tags with valid characters

## Quick Reference Files

### main.tf
```hcl
module "web_servers" {
  source = "git::https://github.com/phuru7/terraform-aws-ec2.git"
  
  environment    = var.environment
  company_name   = var.company_name
  project_name   = var.project_name
  
  network_config = {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    eip_count          = var.eip_count
  }
  
  key_pair_config = {
    create_new        = false
    existing_key_name = var.key_name
  }
  
  tags = var.common_tags
}
```

### variables.tf
```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "company_name" {
  description = "Company name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "eip_count" {
  description = "Number of Elastic IPs"
  type        = number
  default     = 0
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
```

### outputs.tf
```hcl
output "instance_ids" {
  description = "EC2 instance IDs"
  value       = [for instance in module.web_servers.instances_info.instances : instance.id]
}

output "private_ips" {
  description = "Private IP addresses"
  value       = module.web_servers.network_info.instances_network.private_ips
}

output "public_ips" {
  description = "Public IP addresses"
  value       = module.web_servers.network_info.instances_network.public_ips
}

output "ssh_connection" {
  description = "SSH connection strings"
  value = [
    for conn in module.web_servers.connection_info :
    "ssh -i ~/.ssh/${conn.connection.key_name}.pem ${conn.connection.user}@${conn.host}"
  ]
}

output "instance_names" {
  description = "Instance names"
  value = [for instance in module.web_servers.instances_info.instances : instance.name]
}
```

### terraform.tfvars
```hcl
# Basic configuration
environment    = "dev"
company_name   = "acme"
project_name   = "webapp"

# Network
subnet_ids         = ["subnet-12345678", "subnet-87654321"]
security_group_ids = ["sg-abcdef123"]

# Key pair
key_name = "my-ec2-key"

# Elastic IPs (optional)
eip_count = 1

# Tags
common_tags = {
  Owner       = "DevOps Team"
  Environment = "development"
  Project     = "Web Application"
  CostCenter  = "Engineering"
  Terraform   = "true"
}
```

## Deployment Commands

```bash
# Initialize
terraform init

# Plan
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars"

# Destroy
terraform destroy -var-file="terraform.tfvars"
```

## Best Practices

1. **Use tfvars files per environment**
2. **Apply consistent tags for billing**
3. **Enable monitoring in staging and prod**
4. **Use encrypted volumes (default)**
5. **Configure termination protection in prod**
6. **Distribute instances across multiple AZs**

## Limitations

- Maximum 100 instances per deployment
- EBS volumes up to 16TB
- EIPs limited by AWS quota
- Key pairs must exist previously if not created