variable "environment" { type = string }
variable "force_destroy" { type = bool; default = false }
variable "price_class" { type = string; default = "PriceClass_100" }
variable "default_ttl" { type = number; default = 3600 }
variable "max_ttl" { type = number; default = 86400 }
variable "tags" { type = map(string); default = {} }
