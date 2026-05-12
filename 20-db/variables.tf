variable  "project_name" {
  default = "expense"
}
variable "environment" {
   default =  "dev"
}
variable "common_tags" {
    type = map
    default = {
        Terraform = "true"
        Environment = "Dev"
        Project = "expense"
    }
}
variable "zone_name" {
  default =  "lithesh.shop"
}
