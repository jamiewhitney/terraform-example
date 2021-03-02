variable "name" {
  type        = string
  default     = ""
  description = "description"
}

variable "ami" {
  type        = string
  default     = ""
  description = "description"
}

variable "instance_type" {
  type        = string
  default     = ""
  description = "description"
}

variable "azs" {
  type        = set(string)
  default     = [""]
  description = "description"
}

variable "subnets" {
  type        = set(string)
  description = "description"
}

variable "vpc_id" {
  type = string
}

variable "user_data" {
  type = string
}

variable "desired_capacity" {
  type = number
}

variable "max_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "security_groups" {
  type = string
}

variable "alb" {}