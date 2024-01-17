terraform {
  backend "s3" {
    bucket                  = "terraformstate-9e41286e"
    key                     = "personalcloud"
    region                  = "eu-west-3"
  }
}
