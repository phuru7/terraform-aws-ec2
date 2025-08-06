<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | n/a | <pre>object({<br/>    instances   = optional(map(string), {})<br/>    volumes     = optional(map(string), {})<br/>    root_volume = optional(map(string), {})<br/>    key_pairs   = optional(map(string), {})<br/>    eips        = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_ami_filters"></a> [ami\_filters](#input\_ami\_filters) | List of filters to find AMI. Used when ami\_id is null | <pre>list(object({<br/>    name   = string<br/>    values = list(string)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "name": "name",<br/>    "values": [<br/>      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"<br/>    ]<br/>  },<br/>  {<br/>    "name": "state",<br/>    "values": [<br/>      "available"<br/>    ]<br/>  }<br/>]</pre> | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to use for instances. If null, will use latest AMI based on filters | `string` | `null` | no |
| <a name="input_ami_owners"></a> [ami\_owners](#input\_ami\_owners) | List of AMI owners to limit search. Used when ami\_id is null | `list(string)` | <pre>[<br/>  "099720109477"<br/>]</pre> | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Associate public IP address to instances | `bool` | `false` | no |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Name of the company (used in naming pattern) | `string` | n/a | yes |
| <a name="input_disable_api_stop"></a> [disable\_api\_stop](#input\_disable\_api\_stop) | Enable EC2 instance stop protection | `bool` | `false` | no |
| <a name="input_disable_api_termination"></a> [disable\_api\_termination](#input\_disable\_api\_termination) | Enable EC2 instance termination protection | `bool` | `false` | no |
| <a name="input_ebs_block_devices"></a> [ebs\_block\_devices](#input\_ebs\_block\_devices) | Additional EBS block devices to attach to instances | <pre>list(object({<br/>    device_name           = string<br/>    custom_name           = string <br/>    volume_type           = string<br/>    volume_size           = number<br/>    iops                  = optional(number)<br/>    throughput            = optional(number)<br/>    encrypted             = optional(bool, true)<br/>    kms_key_id            = optional(string)<br/>    snapshot_id           = optional(string)<br/>    delete_on_termination = optional(bool, true)<br/>    tags                  = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_eip_count"></a> [eip\_count](#input\_eip\_count) | Number of Elastic IPs to create (0 to instance\_count). Set to 0 for no EIPs | `number` | `0` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, qa, prod, etc.) | `string` | n/a | yes |
| <a name="input_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#input\_iam\_instance\_profile\_name) | Name of IAM instance profile to attach to instances | `string` | `null` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of EC2 instances to create | `number` | n/a | yes |
| <a name="input_instance_initiated_shutdown_behavior"></a> [instance\_initiated\_shutdown\_behavior](#input\_instance\_initiated\_shutdown\_behavior) | Shutdown behavior for the instance | `string` | `"stop"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type | `string` | `"t3.micro"` | no |
| <a name="input_key_pair_config"></a> [key\_pair\_config](#input\_key\_pair\_config) | Key pair configuration | <pre>object({<br/>    create_new        = optional(bool, false)<br/>    public_key        = optional(string)<br/>    existing_key_name = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_monitoring"></a> [monitoring](#input\_monitoring) | Enable detailed monitoring for instances | `bool` | `false` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project (used in naming pattern) | `string` | n/a | yes |
| <a name="input_root_volume"></a> [root\_volume](#input\_root\_volume) | Root volume configuration | <pre>object({<br/>    type                  = optional(string, "gp3")<br/>    size                  = optional(number, 20)<br/>    iops                  = optional(number)<br/>    throughput            = optional(number)<br/>    encrypted             = optional(bool, true)<br/>    kms_key_id            = optional(string)<br/>    delete_on_termination = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security group IDs to assign to the instances | `list(string)` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs where instances will be created. Instances will be distributed across subnets | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | User data script for instances (will auto-detect if base64 encoded) | `string` | `null` | no |
| <a name="input_user_data_replace_on_change"></a> [user\_data\_replace\_on\_change](#input\_user\_data\_replace\_on\_change) | Replace instance if user data changes | `bool` | `false` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_info"></a> [connection\_info](#output\_connection\_info) | SSH/RDP connection information for external tools (Ansible, etc.) |
| <a name="output_eip_info"></a> [eip\_info](#output\_eip\_info) | Elastic IP information |
| <a name="output_instances_info"></a> [instances\_info](#output\_instances\_info) | Complete summary of all instances with essential information |
| <a name="output_key_pair_info"></a> [key\_pair\_info](#output\_key\_pair\_info) | Key pair information used by instances |
| <a name="output_network_info"></a> [network\_info](#output\_network\_info) | Complete network information for all instances |
<!-- END_TF_DOCS -->