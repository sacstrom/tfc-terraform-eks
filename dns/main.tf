provider "aws" {
  region = var.region
  profile = "terraform-mvp"
}

provider "aws" {
  alias   = "dns"
  region  = var.region
  profile = "terraform-dns"
}