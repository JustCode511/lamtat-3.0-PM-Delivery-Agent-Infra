output "dynamodb_tables" {
  description = "Created DynamoDB table names."
  value = {
    sessions       = aws_dynamodb_table.sessions.name
    users          = aws_dynamodb_table.users.name
    revoked_tokens = aws_dynamodb_table.revoked_tokens.name
    conversations  = aws_dynamodb_table.conversations.name
  }
}
