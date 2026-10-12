# Example Multi-Instance RDS-NLB Configuration
# Copy this configuration to your environment's terragrunt.hcl file

inputs = {
  environment        = "dev"  # or "pst", "prd"
  project           = "snowflake"
  cost_centre       = "one-data"
  capability        = "rds-dns-resolver"
  log_retention_days = 30
  retain_lambda_logs = true
  
  # RDS-NLB Mappings - Each key creates a separate Lambda function
  rds_nlb_mappings = {
    
    # Primary Snowflake Database
    "snowflake-primary" = {
      db_identifier    = "snowflake-prod-primary"
      private_link_nlb = "snowflake-primary-nlb"
      port            = 5432
      description     = "Primary Snowflake database for production workloads"
    }
    
    # Analytics Database
    "snowflake-analytics" = {
      db_identifier    = "snowflake-analytics-db"
      private_link_nlb = "snowflake-analytics-nlb"
      port            = 5432
      description     = "Snowflake database for analytics and reporting"
    }
    
    # Development Database
    "snowflake-dev" = {
      db_identifier    = "snowflake-dev-instance"
      private_link_nlb = "snowflake-dev-nlb"
      port            = 5432
      description     = "Development Snowflake database"
    }
    
    # MySQL Database Example (different port)
    "mysql-legacy" = {
      db_identifier    = "legacy-mysql-db"
      private_link_nlb = "mysql-legacy-nlb"
      port            = 3306
      description     = "Legacy MySQL database"
    }
    
    # PostgreSQL Database Example
    "postgres-app" = {
      db_identifier    = "app-postgres-db"
      private_link_nlb = "postgres-app-nlb"
      port            = 5432
      description     = "PostgreSQL database for application data"
    }
  }
}

# This configuration will create:
# - 5 Lambda functions (one for each RDS-NLB pair)
# - 5 EventBridge rules (one for each RDS instance)
# - 5 CloudWatch log groups (one for each Lambda)
# - 1 shared IAM role for all Lambda functions

# Lambda function names will be:
# - dev-snowflake-rds-dns-resolver-snowflake-primary-lambda
# - dev-snowflake-rds-dns-resolver-snowflake-analytics-lambda
# - dev-snowflake-rds-dns-resolver-snowflake-dev-lambda
# - dev-snowflake-rds-dns-resolver-mysql-legacy-lambda
# - dev-snowflake-rds-dns-resolver-postgres-app-lambda

# EventBridge rules will monitor:
# - snowflake-prod-primary (restart events)
# - snowflake-analytics-db (restart events)
# - snowflake-dev-instance (restart events)
# - legacy-mysql-db (restart events)
# - app-postgres-db (restart events)

# Each Lambda will register targets with their respective NLBs:
# - snowflake-primary-nlb (port 5432)
# - snowflake-analytics-nlb (port 5432)
# - snowflake-dev-nlb (port 5432)
# - mysql-legacy-nlb (port 3306)
# - postgres-app-nlb (port 5432)
