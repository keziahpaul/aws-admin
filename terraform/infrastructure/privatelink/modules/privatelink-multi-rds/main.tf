data "aws_subnets" "privatelink" {
  filter {
    name   = "tag:Name"
    values = ["PrivateLinkSubnet*"]
  }
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_lb" "nlb" {
  name                             = "${var.environment}-${var.project}-privatelink-nlb"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = data.aws_subnets.privatelink.ids
  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.security_group.id]

  access_logs {
    bucket  = "pexa-loadbalancer-logs"
    enabled = var.nlb_access_logs_enabled || var.environment == "pst" || var.environment == "prd"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project}-privatelink-nlb",
      Environment = var.environment,
      Project     = var.project,
      Cost-Centre = var.cost_centre
    }
  )
}

# Target groups - one per RDS instance
resource "aws_lb_target_group" "rds" {
  for_each = var.target_groups

  name        = "${var.environment}-${var.project}-${each.key}-tg"
  port        = each.value.target_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = each.value.target_port
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project}-${each.key}-tg"
      Description = each.value.description
    }
  )
}

# Listeners - one per RDS instance
resource "aws_lb_listener" "rds" {
  for_each = var.target_groups

  load_balancer_arn = aws_lb.nlb.arn
  port              = each.value.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rds[each.key].arn
  }
}

resource "aws_security_group" "security_group" {
  name        = "${var.environment}-${var.project}-nlb-sg"
  description = "Security Group for the PrivateLink Network Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.ingress_from_port
    to_port     = var.ingress_to_port
    protocol    = var.ingress_protocol_type
    cidr_blocks = var.ingress_cidr_block
  }

  egress {
    from_port       = var.custom_egress_from_port
    to_port         = var.custom_egress_to_port
    protocol        = var.custom_egress_protocol_type
    security_groups = var.custom_security_group_id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.project}-nlb-sg",
    }
  )
}

resource "aws_vpc_endpoint_service" "nlb_vpce_service" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.nlb.arn]
  allowed_principals         = var.allowed_principals

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project}-nlb-vpce-service",
      Project     = var.project,
      Cost-Centre = var.cost_centre
    }
  )
}
