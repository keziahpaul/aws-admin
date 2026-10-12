# Common environment configuration for datanp/tst
locals {
  environment = "tst"

  # TODO: replace with real VPC ID from the datanp account
  vpc_id             = "vpc-0placeholder"
  private_subnet_ids = ["subnet-0placeholder1", "subnet-0placeholder2"]

  use_fargate_spot             = true
  create_opensearch_collection = true
}
