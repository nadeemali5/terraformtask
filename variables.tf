variable "aws_access_key_id" {
  description = "Access key Value"
  type = string
  
}

variable "aws_secret_access_key" {
  description = "Secret key value"
  type = string
  
}

variable "vpc_cidr" { 
  description = "The CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnets"
  type        = list(string)
}
