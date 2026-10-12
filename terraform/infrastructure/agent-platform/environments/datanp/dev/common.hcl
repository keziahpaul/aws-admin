# Common environment configuration for datanp/dev
locals {
  environment = "dev"

  # datanp DEVVPC
  vpc_id             = "vpc-67e19503"
  private_subnet_ids = ["subnet-39704c5d", "subnet-ed9cbf9b", "subnet-71422028"]

  use_fargate_spot             = true
  create_opensearch_collection = true
}
