provider "vault" {}

resource "vault_mount" "example" {
  path    = "example"
  type    = "kv-v2"
  options = { version = "2" }
}

resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.example.path

  name                = "unsecret"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      ani  = "dev",
      siva = "dev",
      tony = "stark",
      thor = "odinson",
      role = "tfc-role-new",
      bgt  = "3-1",
      road = "block",
      tropic = "format",
      max = "verstappen"
    }
  )
}