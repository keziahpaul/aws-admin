output "rds_dns_resolver_lambda_role_arn" {
  description = "The ARN of the RDS DNS Resolver Lambda Role"
  value       = aws_iam_role.rds_dns_resolver_lambda_role.arn
}

output "rds_dns_resolver_code_signing_config" {
  description = "Code signing configuration details for Lambda functions"
  value = {
    arn                     = aws_lambda_code_signing_config.rds_dns_resolver_code_signing.arn
    config_id               = aws_lambda_code_signing_config.rds_dns_resolver_code_signing.config_id
    signing_profile_arn     = aws_signer_signing_profile.rds_dns_resolver_signing_profile.arn
    signing_profile_name    = aws_signer_signing_profile.rds_dns_resolver_signing_profile.name
    signing_profile_version = aws_signer_signing_profile.rds_dns_resolver_signing_profile.version_arn
    enforcement_policy      = "Enforce"
  }
  sensitive = false
}

output "rds_dns_resolver_lambda_functions" {
  description = "Map of Lambda function details for each RDS-NLB pair"
  value = {
    for key, lambda in aws_lambda_function.rds_dns_resolver_lambda : key => {
      arn                     = lambda.arn
      function_name           = lambda.function_name
      code_signing_config_arn = lambda.code_signing_config_arn
      db_identifier           = lambda.environment[0].variables.DB_IDENTIFIER
      nlb_name                = lambda.environment[0].variables.PRIVATE_LINK_NLB
      port                    = lambda.environment[0].variables.TARGET_PORT
      security_compliant      = true
    }
  }
}

output "eventbridge_rules" {
  description = "Map of EventBridge rule details for each RDS instance"
  value = {
    for key, rule in aws_cloudwatch_event_rule.eventbridge_trigger_rule : key => {
      arn  = rule.arn
      name = rule.name
    }
  }
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group details for each Lambda function"
  value = {
    for key, log_group in aws_cloudwatch_log_group.rds_dns_resolver_lambda_log_group : key => {
      name = log_group.name
      arn  = log_group.arn
    }
  }
}

output "rds_nlb_mappings_summary" {
  description = "Summary of all RDS-NLB mappings configured"
  value = {
    for key, mapping in var.rds_nlb_mappings : key => {
      db_identifier    = mapping.db_identifier
      private_link_nlb = mapping.private_link_nlb
      port             = mapping.port
      description      = mapping.description
      lambda_function  = "${var.environment}-${var.project}-${var.capability}-${key}-lambda"
    }
  }
}
