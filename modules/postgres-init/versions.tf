terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # provider 설정은 env(root)에서 하고 providers = { postgresql = ... } 로 주입받는다.
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
  }
}
