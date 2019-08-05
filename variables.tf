variable "name" {}
variable "git_projects" {
  #https://github.com/hashicorp/terraform/issues/19898
  type = any
}
