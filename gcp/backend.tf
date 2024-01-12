terraform {
  backend "gcs" {
    bucket = "tfstate-1782c91e-b06f-11ee-89d6-672aa30fbfc2"
    prefix = "terraform/state"
  }
}
