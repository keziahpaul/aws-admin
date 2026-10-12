# ---------------------------------------------------------------------------
# Secrets Manager module
#
# Two modes:
#   1. `var.secrets`              — create new secrets with a PLACEHOLDER value.
#   2. `var.existing_secret_arns` — reference pre-existing secrets (data source,
#                                   no resources created).
#
# Both modes produce entries in `secret_arns` so consumers have a unified
# interface regardless of where the secret lives.
# ---------------------------------------------------------------------------

# --- Created secrets ---

resource "aws_secretsmanager_secret" "created" {
  for_each = var.secrets

  name                    = "${var.environment}/${var.agent_name}-agent/${each.key}"
  description             = each.value.description != "" ? each.value.description : "Secret for ${var.agent_name} agent: ${each.key}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name       = "${var.environment}/${var.agent_name}-agent/${each.key}"
    SecretType = each.key
  })
}

resource "aws_secretsmanager_secret_version" "created" {
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.created[each.key].id

  # PLACEHOLDER value — must be replaced before starting the service.
  # lifecycle ignore_changes ensures Terraform never overwrites a real value
  # after the initial placeholder creation.
  secret_string = jsonencode({
    value = "PLACEHOLDER-replace-before-starting-service"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# --- Existing secrets (BYO — reference only, no resource created) ---

data "aws_secretsmanager_secret" "existing" {
  for_each = var.existing_secret_arns

  arn = each.value
}
