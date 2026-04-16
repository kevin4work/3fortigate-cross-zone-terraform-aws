# Randomize string to avoid duplication
resource "random_string" "random_name_post" {
  length           = 3
  special          = true
  override_special = ""
  min_lower        = 3
}

provider "aws" {
  region     = var.region
  profile    = "fortinet-admin"
}
