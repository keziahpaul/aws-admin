data "aws_caller_identity" "current" {}

resource "aws_dms_replication_config" "onedata_exchange_dms_task" {
  replication_config_identifier = "${var.environment}-onedata-exchange-set2-serverless-full-cdc"
  replication_type             = "full-load-and-cdc"
  
  compute_config {
    multi_az                     = true
    min_capacity_units          = var.min_dcu
    max_capacity_units          = var.max_dcu
    preferred_maintenance_window = "Sun:11:00-Sun:13:00"
    replication_subnet_group_id = var.dms_subnet_group
    vpc_security_group_ids      = [var.security_group_id]
  }

  replication_settings = jsonencode({
    Logging = {
      EnableLogging = true
    }
    TargetMetadata = {
      LobMaxSize = 16384
    }
    FullLoadSettings = {
      MaxFullLoadSubTasks   = 24
      TargetTablePrepMode   = "DO_NOTHING"
    }
  })

  source_endpoint_arn = "arn:aws:dms:ap-southeast-2:${data.aws_caller_identity.current.account_id}:endpoint:onedata-exchange-src-db-${var.environment}"
  target_endpoint_arn = "arn:aws:dms:ap-southeast-2:${data.aws_caller_identity.current.account_id}:endpoint:onedata-exchange-tgt-s3-${var.environment}"

  table_mappings = jsonencode({
    rules = [
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "1"
        rule-name   = "residual_configs"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_residual_configs"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "2"
        rule-name   = "residuals"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_residuals"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "3"
        rule-name   = "correspondences"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_correspondences"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "4"
        rule-name   = "subscriber_correspondence"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_subscriber_correspondence"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "5"
        rule-name   = "conversations_read_ref"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_conversations_read_ref"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "6"
        rule-name   = "simultaneous_workspaces"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_simultaneous_workspaces"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "7"
        rule-name   = "simultaneous_lodgements"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_simultaneous_lodgements"
        }
        filters = []
      },
      {
        rule-type   = "selection"
        rule-action = "include"
        rule-id     = "8"
        rule-name   = "event_log_type"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_event_log_type"
        }
        filters = []
      },
      {
        rule-type = "transformation"
        rule-id   = "9"
        rule-name = "residual_configs_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_residual_configs"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "10"
        rule-name = "residuals_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_residuals"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "11"
        rule-name = "correspondences_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_correspondences"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "12"
        rule-name = "subscriber_correspondence_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_subscriber_correspondence"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "13"
        rule-name = "conversations_read_ref_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_conversations_read_ref"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "14"
        rule-name = "simultaneous_workspaces_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_simultaneous_workspaces"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "15"
        rule-name = "simultaneous_lodgements_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_simultaneous_lodgements"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      },
      {
        rule-type = "transformation"
        rule-id   = "16"
        rule-name = "event_log_type_trn_seq"
        rule-target = "column"
        object-locator = {
          schema-name = "pexa"
          table-name  = "pxa_event_log_type"
        }
        rule-action = "add-column"
        value = "transact_seq"
        expression = "$AR_H_CHANGE_SEQ"
        data-type = {
          type = "string"
          length = 50
        }
      }
    ]
  })

  tags = {
    environment = var.environment
    team        = "onedata"
  }
}