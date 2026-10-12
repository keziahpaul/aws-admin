# Common environment configuration for dataprd/pst
locals {
  environment = "pst"

  # TODO: replace with real VPC ID from the dataprd account
  vpc_id             = "vpc-0placeholder"
  private_subnet_ids = ["subnet-0placeholder1", "subnet-0placeholder2"]

  use_fargate_spot             = false
  create_opensearch_collection = true
}
