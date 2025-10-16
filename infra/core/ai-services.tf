# Data source for existing Azure OpenAI account
data "azurerm_cognitive_account" "openai" {
  name                = "bensincs" # Your OpenAI account name from the endpoint
  resource_group_name = "OpenAI"
}

# Grant AI Chat Service managed identity access to Azure OpenAI
resource "azurerm_role_assignment" "ai_chat_openai_user" {
  scope                = data.azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.ai_chat.principal_id
}
