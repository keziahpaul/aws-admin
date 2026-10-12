import boto3
import socket
import os

def lambda_handler(event, context):
    """
    Lambda function to register RDS instance IP addresses with NLB target group
    when the RDS instance is restarted.
    
    Finds the correct target group by matching the listener port.
    """
    
    # Get configuration from environment variables (preferred) or event
    region = event.get('region', os.environ.get('AWS_REGION', 'ap-southeast-2'))
    db_identifier = event.get('db_identifier', os.environ.get('DB_IDENTIFIER'))
    privatelink_nlb = event.get('privatelink_nlb', os.environ.get('PRIVATE_LINK_NLB'))
    listener_port = int(event.get('port', os.environ.get('TARGET_PORT', 5432)))
    
    # Validate required parameters
    if not db_identifier:
        raise ValueError("db_identifier is required (from event or DB_IDENTIFIER env var)")
    if not privatelink_nlb:
        raise ValueError("privatelink_nlb is required (from event or PRIVATE_LINK_NLB env var)")
    
    print(f"Processing RDS DNS resolution for:")
    print(f"  Region: {region}")
    print(f"  DB Identifier: {db_identifier}")
    print(f"  Private Link NLB: {privatelink_nlb}")
    print(f"  Listener Port: {listener_port}")
    
    rds_client = boto3.client('rds', region_name=region)
    elbv2_client = boto3.client('elbv2', region_name=region)
    
    try:
        # Get RDS endpoint
        print(f"Retrieving RDS endpoint for {db_identifier}...")
        rds_response = rds_client.describe_db_instances(DBInstanceIdentifier=db_identifier)
        rds_endpoint = rds_response['DBInstances'][0]['Endpoint']['Address']
        rds_port = rds_response['DBInstances'][0]['Endpoint']['Port']
        print(f"✅ RDS Endpoint: {rds_endpoint}:{rds_port}")
    except Exception as e:
        error_msg = f"Error retrieving RDS endpoint for {db_identifier}: {e}"
        print(f"❌ {error_msg}")
        raise Exception(error_msg)
    
    try:
        # Get Load Balancer ARN
        print(f"Retrieving Load Balancer ARN for {privatelink_nlb}...")
        lb_response = elbv2_client.describe_load_balancers(Names=[privatelink_nlb.strip()])
        load_balancer_arn = lb_response['LoadBalancers'][0]['LoadBalancerArn']
        print(f"✅ Load Balancer ARN: {load_balancer_arn}")
    except Exception as e:
        error_msg = f"Error retrieving Load Balancer ARN for {privatelink_nlb}: {e}"
        print(f"❌ {error_msg}")
        raise Exception(error_msg)
    
    try:
        # Get all listeners and find the one matching our port
        print(f"Finding listener on port {listener_port}...")
        listeners_response = elbv2_client.describe_listeners(LoadBalancerArn=load_balancer_arn)
        
        target_group_arn = None
        for listener in listeners_response['Listeners']:
            if listener['Port'] == listener_port:
                target_group_arn = listener['DefaultActions'][0]['TargetGroupArn']
                print(f"✅ Found listener on port {listener_port}")
                print(f"✅ Target Group ARN: {target_group_arn}")
                break
        
        if not target_group_arn:
            raise Exception(f"No listener found on port {listener_port} for Load Balancer {load_balancer_arn}")
            
    except Exception as e:
        error_msg = f"Error finding target group for listener port {listener_port}: {e}"
        print(f"❌ {error_msg}")
        raise Exception(error_msg)
    
    try:
        # Resolve RDS endpoint to IP address
        print(f"Resolving IP address for {rds_endpoint}...")
        ip_address = socket.gethostbyname(rds_endpoint)
        print(f"✅ Resolved IP Address: {ip_address}")
    except Exception as e:
        error_msg = f"Error resolving IP address for {rds_endpoint}: {e}"
        print(f"❌ {error_msg}")
        raise Exception(error_msg)
    
    try:
        # Register target with target group
        print(f"Registering target {ip_address}:{rds_port} with target group...")
        elbv2_client.register_targets(
            TargetGroupArn=target_group_arn,
            Targets=[
                {
                    'Id': ip_address,
                    'Port': rds_port
                },
            ]
        )
        success_msg = f"Successfully registered {ip_address}:{rds_port} with target group (listener port {listener_port})"
        print(f"✅ {success_msg}")
    except Exception as e:
        error_msg = f"Error registering target {ip_address}:{rds_port} with target group {target_group_arn}: {e}"
        print(f"❌ {error_msg}")
        raise Exception(error_msg)
    
    return {
        'statusCode': 200,
        'body': {
            'message': f"Successfully registered {ip_address}:{rds_port} with target group",
            'details': {
                'db_identifier': db_identifier,
                'rds_endpoint': rds_endpoint,
                'ip_address': ip_address,
                'rds_port': rds_port,
                'listener_port': listener_port,
                'privatelink_nlb': privatelink_nlb,
                'target_group_arn': target_group_arn
            }
        }
    }
