# How RDS DNS Resolver Works with Multiple Target Groups

## Overview

The Lambda function finds the correct target group by **matching the listener port**, then registers the RDS IP to that specific target group.

## Flow

```
1. RDS restarts → EventBridge triggers Lambda
2. Lambda receives: db_identifier + listener_port (e.g., 5433)
3. Lambda queries NLB listeners
4. Finds listener on port 5433
5. Gets target group ARN from that listener
6. Resolves RDS IP address
7. Registers IP to that specific target group
```

## Key Changes in Lambda

### Old Logic (Broken for Multiple RDS)
```python
# Gets FIRST target group - wrong!
tg_response = elbv2_client.describe_target_groups(LoadBalancerArn=load_balancer_arn)
target_group_arn = tg_response['TargetGroups'][0]['TargetGroupArn']
```

### New Logic (Works for Multiple RDS)
```python
# Finds target group by listener port - correct!
listeners_response = elbv2_client.describe_listeners(LoadBalancerArn=load_balancer_arn)

for listener in listeners_response['Listeners']:
    if listener['Port'] == listener_port:  # Match by port
        target_group_arn = listener['DefaultActions'][0]['TargetGroupArn']
        break
```

## Configuration Mapping

### PrivateLink Config
```hcl
target_groups = {
  "nlb" = {
    target_port   = 5432
    listener_port = 5432  # NLB listens on 5432
    description   = "RDS 1"
  }
  "gapinotif" = {
    target_port   = 5432
    listener_port = 5433  # NLB listens on 5433
    description   = "RDS 2"
  }
}
```

### RDS DNS Resolver Config
```hcl
rds_nlb_mappings = {
  "rds1-db" = {
    db_identifier    = "rds1"
    private_link_nlb = "dev-snowflake-privatelink-nlb"
    port            = 5432  # Matches listener_port above
    description     = "RDS 1"
  }
  "rds2-db" = {
    db_identifier    = "rds2"
    private_link_nlb = "dev-snowflake-privatelink-nlb"
    port            = 5433  # Matches listener_port above
    description     = "RDS 2"
  }
}
```

## Example Execution

### Lambda for RDS 1 (port 5432)
```
Input: { db_identifier: "rds1", port: 5432 }

1. Query NLB listeners
2. Find listener on port 5432
3. Get target group: dev-snowflake-nlb-tg
4. Resolve rds1 IP: 10.0.1.10
5. Register 10.0.1.10 to dev-snowflake-nlb-tg
```

### Lambda for RDS 2 (port 5433)
```
Input: { db_identifier: "rds2", port: 5433 }

1. Query NLB listeners
2. Find listener on port 5433
3. Get target group: dev-snowflake-gapinotif-tg
4. Resolve rds2 IP: 10.0.1.20
5. Register 10.0.1.20 to dev-snowflake-gapinotif-tg
```

## Result

```
NLB
├── Listener 5432 → TG nlb → RDS1 IP (10.0.1.10)
└── Listener 5433 → TG gapinotif → RDS2 IP (10.0.1.20)

Connections:
- vpce-xxx:5432 → RDS 1
- vpce-xxx:5433 → RDS 2
```

## Testing

```bash
# Test Lambda for RDS 1
aws lambda invoke \
  --function-name dev-snowflake-rds-dns-resolver-rds1-db-lambda \
  --payload '{"db_identifier":"rds1","privatelink_nlb":"dev-snowflake-privatelink-nlb","port":5432}' \
  response.json

# Test Lambda for RDS 2
aws lambda invoke \
  --function-name dev-snowflake-rds-dns-resolver-rds2-db-lambda \
  --payload '{"db_identifier":"rds2","privatelink_nlb":"dev-snowflake-privatelink-nlb","port":5433}' \
  response.json

# Verify target registration
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>
```

## Important

The `port` parameter in RDS DNS Resolver config **must match** the `listener_port` in PrivateLink config:

```hcl
# PrivateLink
target_groups = {
  "gapinotif" = {
    listener_port = 5433  # ← This
  }
}

# RDS DNS Resolver
rds_nlb_mappings = {
  "rds2-db" = {
    port = 5433  # ← Must match this
  }
}
```
