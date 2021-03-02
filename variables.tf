variable "azs" {
  type        = set(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  description = "description"
}

variable "name" {
  type        = string
  default     = ""
  description = "description"
}

variable "tags" {
  type        = map(string)
  default     = { "" : "" }
  description = "description"
}

variable "domainName" {}

variable "region" {}