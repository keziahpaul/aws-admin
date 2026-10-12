variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "The environment to deploy the resources"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to deploy the NLB and Security Group resources"
  type        = string
}

variable "project" {
  description = "The name of the project"
  type        = string
}

variable "cost_centre" {
  description = "The cost centre for the project"
  type        = string
}

variable "nlb_access_logs_enabled" {
  description = "The boolean value to enable or disable the NLB access logs"
  type        = bool
  default     = false
}

variable "ingress_from_port" {
  description = "The start port for the ingress rule"
  type        = number
}

variable "ingress_to_port" {
  description = "The end port for the ingress rule"
  type        = number
}

variable "ingress_protocol_type" {
  description = "The protocol type for the Security Group ingress rule"
  type        = string
  default     = "tcp"
}

variable "ingress_cidr_block" {
  description = "The CIDR block for the ingress rule"
  type        = list(string)
  default     = []
}

variable "custom_egress_from_port" {
  description = "The start port for the custom egress rule"
  type        = number
}

variable "custom_egress_to_port" {
  description = "The end port for the custom egress rule"
  type        = number
}

variable "custom_egress_protocol_type" {
  description = "The protocol type for the custom Security Group egress rule"
  type        = string
  default     = "tcp"
}

variable "custom_security_group_id" {
  description = "The SG ID of the RDS/EC2 instance for the NLB to connect to"
  type        = list(string)
  default     = []
}

variable "allowed_principals" {
  description = "The list of allowed principals for the VPC Endpoint Service"
  type        = list(string)
  default     = []
}

variable "target_groups" {
  description = "Map of target groups for RDS instances"
  type = map(object({
    target_port   = number
    listener_port = number
    description   = string
  }))
}
