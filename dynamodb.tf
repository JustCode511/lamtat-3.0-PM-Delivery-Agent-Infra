# ── DynamoDB tables ──────────────────────────────────────────
# All PAY_PER_REQUEST (on-demand) → zero cost when idle.
# Table names match the defaults hardcoded in the backend adapters, so no code
# change is needed (DynamoSessionStore("pm_sessions"), DynamoUserStore("pm_users"),
# DynamoTokenDenylist("pm_revoked_tokens"), DynamoConversationStore("pm_conversations")).
#
# DynamoDB is schemaless: only KEY attributes are declared here. Non-key fields
# (history, password_hash, messages, title, ...) are written by the app as needed.

# Agent short-term working memory (auto-expires via TTL "ttl").
resource "aws_dynamodb_table" "sessions" {
  name         = "pm_sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# User credentials (username -> PBKDF2 hash + salt).
resource "aws_dynamodb_table" "users" {
  name         = "pm_users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"

  attribute {
    name = "username"
    type = "S"
  }
}

# Revoked JWTs for sign-out (auto-expires via TTL "ttl" once the token would).
resource "aws_dynamodb_table" "revoked_tokens" {
  name         = "pm_revoked_tokens"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jti"

  attribute {
    name = "jti"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# Durable long-term memory: rolling session summaries + cross-session user facts.
# Single table keyed by a prefixed pk (summary#<session_id> / user#<user_id>).
resource "aws_dynamodb_table" "memory" {
  name         = "pm_memory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }
}

# Permanent conversation archive for the history sidebar.
# GSI "user_id-index" powers list_conversations(user_id).
resource "aws_dynamodb_table" "conversations" {
  name         = "pm_conversations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "user_id-index"
    hash_key        = "user_id"
    projection_type = "ALL"
  }
}
