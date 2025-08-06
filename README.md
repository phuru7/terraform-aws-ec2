# terraform-aws-ec2

Módulo de Terraform para crear instancias EC2 con configuración flexible, volúmenes EBS adicionales, IPs elásticas y gestión de key pairs.

## Arquitectura

Este módulo crea:
- Instancias EC2 con distribución automática en múltiples subnets
- Volúmenes EBS adicionales con attachment automático
- IPs elásticas configurables
- Key pairs (nuevos o existentes)
- Tags organizados por tipo de recurso

## Requisitos

- Terraform >= 1.0
- AWS Provider >= 5.0
- Credenciales AWS configuradas
- VPC y subnets existentes
- Security groups configurados

## Uso

```hcl
module "app_servers" {
  source = "./terraform-aws-ec2-compute"
  
  # Configuración base
  project_name   = "mi-aplicacion"
  environment    = "prod"
  company_name   = "mi-empresa"
  
  # Instancias
  instance_count = 2
  instance_type  = "t3.medium"
  subnet_ids     = ["subnet-12345", "subnet-67890"]
  security_group_ids = ["sg-abcdef"]
  
  # Key pair
  key_pair_config = {
    create_new = false
    existing_key_name = "mi-key-existente"
  }
  
  # Storage adicional
  ebs_block_devices = [
    {
      device_name = "/dev/sdf"
      custom_name = "data"
      volume_type = "gp3"
      volume_size = 100
      encrypted   = true
    }
  ]
  
  # IPs elásticas (opcional)
  eip_count = 1
  
  tags = {
    Owner       = "DevOps"
    Environment = "production"
  }
}
```

## Variables

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| project_name | string | - | Nombre del proyecto (obligatorio) |
| environment | string | - | Ambiente (dev/qa/prod) (obligatorio) |
| company_name | string | - | Nombre de la empresa (obligatorio) |
| instance_count | number | - | Número de instancias EC2 a crear |
| instance_type | string | t3.micro | Tipo de instancia EC2 |
| subnet_ids | list(string) | - | Lista de subnet IDs donde crear las instancias |
| security_group_ids | list(string) | - | Lista de security group IDs |
| ami_id | string | null | AMI ID específico (usa filtros si es null) |
| ami_owners | list(string) | ["099720109477"] | Propietarios de AMI para búsqueda |
| key_pair_config | object | {} | Configuración de key pair (crear/usar existente) |
| eip_count | number | 0 | Número de IPs elásticas (0 a instance_count) |
| associate_public_ip_address | bool | false | Asignar IP pública automáticamente |
| root_volume | object | {type="gp3", size=20, encrypted=true} | Configuración del volumen root |
| ebs_block_devices | list(object) | [] | Lista de volúmenes EBS adicionales |
| monitoring | bool | false | Habilitar monitoreo detallado |
| disable_api_termination | bool | false | Protección contra terminación |
| iam_instance_profile_name | string | null | Nombre del instance profile IAM |
| user_data | string | null | Script de user data |
| tags | map(string) | {} | Tags comunes para todos los recursos |
| additional_tags | object | {} | Tags específicos por tipo de recurso |

## Outputs

| Output | Descripción |
|--------|-------------|
| instances_info | Información completa de todas las instancias |
| network_info | Información de red (IPs públicas/privadas, DNS) |
| connection_info | Información para conexión SSH/RDP |
| eip_info | Información de IPs elásticas |
| key_pair_info | Información del key pair usado |

## Ejemplos

Ver directorio `examples/` para casos de uso completos:
- `examples/basic/` - Configuración básica con una instancia
- `examples/multi-instance/` - Múltiples instancias con EBS
- `examples/with-eips/` - Instancias con IPs elásticas

## Deployment

```bash
# Inicializar
terraform init

# Planificar cambios
terraform plan -var-file="terraform.tfvars"

# Aplicar
terraform apply -var-file="terraform.tfvars"

# Destruir
terraform destroy -var-file="terraform.tfvars"
```

## Notas Importantes

- Las instancias se distribuyen automáticamente entre las subnets proporcionadas
- El patrón de naming es: `{environment}-{company_name}-{project_name}-{number}`
- Los volúmenes EBS se crean en la misma AZ que la instancia correspondiente
- Las IPs elásticas se asignan secuencialmente a las primeras instancias
- Todos los volúmenes se crean encriptados por defecto
