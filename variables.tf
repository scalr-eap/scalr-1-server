variable "token" {
  description = "Paste in the packagecloud.io token that came with your license file."
  type = string
}

variable "license" {
  description = "Paste in the entire contents of you Scalr license file"
  type = string
  default = "FROM_FILE"
}

variable "region" {
  description = "The AWS Region to deploy in"
  type = string
}

variable "instance_type" {
  description = "Instance type must have minimum of 4GB ram and 30GB disk"
  type = string
}

variable "key_name" {
  description = "The name of then public SSH key to be deployed to the servers. This must exist in AWS already"
  type = string
}

variable "ssh_private_key" {
  description = "The text of SSH Private key. This will be formatted by the Terraform template.<br>This will be used in the remote workspace to allow Terraform to connect to the servers and run scripts to configure Scalr. It only exists in the workspace for the duration of the run."
  type = string
  default = "FROM_FILE"
}

variable "vpc" {
  type = string
}

variable "subnet" {
  type = string
  }

variable "name_prefix" {
  description = "1-3 char prefix for instance names"
  type = string
}
