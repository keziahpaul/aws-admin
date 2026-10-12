data "aws_caller_identity" "current" {}

resource "aws_dms_replication_config" "onedata_exchange_full_cdc" {
  compute_config {
    multi_az                     = true
    min_capacity_units          = var.min_dcu
    max_capacity_units          = var.max_dcu
    preferred_maintenance_window = var.preferred_maintenance_window
    replication_subnet_group_id = var.dms_subnet_group
    vpc_security_group_ids      = [var.security_group_id]
  }

  replication_config_identifier = "${var.environment}-onedata-exchange-serverless-full-cdc"
  replication_type             = "full-load-and-cdc"
  
  replication_settings = jsonencode({
    Logging = {
      EnableLogging = true
    }
    TargetMetadata = {
      LobMaxSize = 16384
    }
    FullLoadSettings = {
      MaxFullLoadSubTasks   = var.max_full_load_sub_tasks
      TargetTablePrepMode   = "DO_NOTHING"
    }
  })

  source_endpoint_arn   = "arn:aws:dms:ap-southeast-2:${data.aws_caller_identity.current.account_id}:endpoint:onedata-exchange-src-db-${var.environment}"
  target_endpoint_arn   = "arn:aws:dms:ap-southeast-2:${data.aws_caller_identity.current.account_id}:endpoint:onedata-exchange-tgt-s3-${var.environment}"
  
  table_mappings = file("table_mappings.json")

  tags = {
    environment = var.environment
    team        = "onedata"
  }
}

