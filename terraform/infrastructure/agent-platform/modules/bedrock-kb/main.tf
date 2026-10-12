data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Bedrock Knowledge Base module
#
# Creates:
#   1. OpenSearch Serverless data access policy — scoped to this agent's index
#      in the shared collection, granting index-level permissions to the
#      bedrock_kb_role_arn.
#   2. Bedrock Knowledge Base (VECTOR / OPENSEARCH_SERVERLESS)
#   3. Bedrock Data Source (S3, RETAIN deletion policy)
#
# Index naming convention: ${var.environment}-${var.agent_name}-index
# This is guaranteed unique by construction across all agents sharing the
# collection (see README.md for the full rationale).
# ---------------------------------------------------------------------------

locals {
  index_name      = "${var.environment}-${var.agent_name}-index"
  # Collection name must match the shared AOSS collection created at root level.
  # Pattern: <env>-agent-platform-kb
  collection_name = var.opensearch_collection_name
}

# ---------------------------------------------------------------------------
# AOSS data access policy
# Grants the Bedrock KB role the minimum set of index permissions required
# to create, populate, and query the agent's dedicated index.
# ---------------------------------------------------------------------------

resource "aws_opensearchserverless_access_policy" "bedrock_kb" {
  name        = "${var.environment}-${var.agent_name}-kb-access"
  type        = "data"
  description = "Bedrock KB access for ${var.agent_name} agent index in shared collection"

  policy = jsonencode([
    {
      Rules = [
        {
          # Collection-level describe permission required by Bedrock service
          ResourceType = "collection"
          Resource     = ["collection/${local.collection_name}"]
          Permission   = ["aoss:DescribeCollectionItems"]
        },
        {
          # Index-level CRUD permissions scoped to this agent's index only
          ResourceType = "index"
          Resource     = ["index/${local.collection_name}/${local.index_name}", "index/${local.collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        },
      ]
      Principal = concat([var.bedrock_kb_role_arn], var.additional_data_access_principals)
    }
  ])
}

# ---------------------------------------------------------------------------
# Bedrock Knowledge Base
# ---------------------------------------------------------------------------

resource "aws_bedrockagent_knowledge_base" "this" {
  name        = "${var.environment}-${var.agent_name}-kb"
  description = "Knowledge base for ${var.agent_name} agent"
  role_arn    = var.bedrock_kb_role_arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"

    opensearch_serverless_configuration {
      collection_arn    = var.opensearch_collection_arn
      vector_index_name = local.index_name

      field_mapping {
        vector_field   = "embedding"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.agent_name}-kb"
  })

  # The AOSS access policy AND index must exist before Bedrock can create the KB
  depends_on = [aws_opensearchserverless_access_policy.bedrock_kb]
}

# ---------------------------------------------------------------------------
# Bedrock Data Source (S3)
# RETAIN deletion policy: index content survives data source deletion,
# preventing accidental loss of ingested KB documents.
# ---------------------------------------------------------------------------

resource "aws_bedrockagent_data_source" "this" {
  name              = "${var.environment}-${var.agent_name}-kb-s3"
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id

  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = var.kb_bucket_arn

      # Scope ingestion to a prefix when provided; omit for full-bucket ingestion
      inclusion_prefixes = var.kb_s3_prefix != "" ? [var.kb_s3_prefix] : null
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = var.chunking_strategy

      dynamic "fixed_size_chunking_configuration" {
        for_each = var.chunking_strategy == "FIXED_SIZE" ? [1] : []
        content {
          max_tokens         = var.chunk_size
          overlap_percentage = var.overlap_percentage
        }
      }

      dynamic "hierarchical_chunking_configuration" {
        for_each = var.chunking_strategy == "HIERARCHICAL" ? [1] : []
        content {
          level_configuration {
            max_tokens = var.hierarchical_parent_chunk_size
          }
          level_configuration {
            max_tokens = var.hierarchical_child_chunk_size
          }
          overlap_tokens = var.hierarchical_overlap_tokens
        }
      }
    }

    dynamic "parsing_configuration" {
      for_each = var.parsing_strategy != "NONE" ? [1] : []
      content {
        parsing_strategy = var.parsing_strategy

        dynamic "bedrock_foundation_model_configuration" {
          for_each = var.parsing_strategy == "BEDROCK_FOUNDATION_MODEL" ? [1] : []
          content {
            model_arn = var.parsing_model_arn
          }
        }
      }
    }
  }
}
