
variable "subnet_id_1" {
  type = string
  default = "subnet-0b2975abd73970e03"
}

variable "subnet_id_2" {
  type = string
  default = "subnet-0a17c9c8adbfb62c2"
}

variable "desired_size" {
  type = string
  default = 3
}
variable "min_size" {
  type = string
  default = 3
}

variable "k8sVersion" {
  default = "1.33"
  type = string
}

variable "cluster_name" {
    default = "eksmlevan-demo"
}