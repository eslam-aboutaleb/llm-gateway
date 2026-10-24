# Terramate Stack Configuration for OCI Production

stack {
  name        = "production"
  description = "Production llm-gateway stack on OCI Always Free"
  id          = "oci-production"
  tags        = ["production", "oci", "arm64", "always-free"]
}

globals {
  environment = "production"
}
