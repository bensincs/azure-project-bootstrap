# AI Chat Service Deployment Checklist

## Prerequisites

- [ ] Azure OpenAI resource created
- [ ] Model deployed in Azure OpenAI (e.g., GPT-4, GPT-3.5)
- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Appropriate RBAC role assigned (Cognitive Services OpenAI User)

## Configuration

- [ ] Copy `.env.example` to `.env` in `services/ai-chat/`
- [ ] Fill in Azure OpenAI details in `.env`:
  - `AZURE_OPENAI_ENDPOINT`
  - `AZURE_OPENAI_DEPLOYMENT_NAME`

## Infrastructure Deployment

- [ ] Navigate to `infra/core/`
- [ ] Run `terraform init` (if first time)
- [ ] Run `terraform plan -var-file=vars/dev.tfvars`
- [ ] Review the plan (look for ai_chat_service resources)
- [ ] Run `terraform apply -var-file=vars/dev.tfvars`
- [ ] Confirm with `yes`

## Service Deployment

- [ ] Navigate to `services/ai-chat/`
- [ ] Ensure `.env` file has correct values
- [ ] Run `./deploy.sh dev`
- [ ] Wait for deployment to complete
- [ ] Note the service URL from output

## Verification

- [ ] Test health endpoint: `curl https://{fqdn}/ai-chat/health`
- [ ] Get service URL: `terraform output ai_chat_service_url`
- [ ] Check logs: `az containerapp logs show --name {app} --resource-group {rg} --follow`
- [ ] Verify service is running in Azure Portal

## UI Integration

- [ ] Update UI `.env` with `VITE_AI_CHAT_URL=https://{fqdn}`
- [ ] Redeploy UI service if needed
- [ ] Test streaming chat in the UI
- [ ] Verify character-by-character typing effect

## Monitoring Setup

- [ ] Check Azure Portal > Container Apps > AI Chat Service
- [ ] View metrics (CPU, Memory, Requests)
- [ ] Set up alerts if needed
- [ ] Monitor Azure OpenAI token usage

## Optional Enhancements

- [ ] Configure custom domain
- [ ] Set up Application Insights
- [ ] Configure CORS if needed
- [ ] Set up staging environment
- [ ] Configure Azure Key Vault for secrets

## Troubleshooting

If deployment fails:
- Check logs: `az containerapp logs show`
- Verify Terraform outputs are correct
- Ensure Azure OpenAI credentials are valid
- Check container registry access
- Verify environment variables in Container App

If streaming doesn't work:
- Check browser console for errors
- Verify SSE connection is established
- Check CORS configuration
- Test with curl to isolate UI vs backend issues

## Success Criteria

✅ Container App is running
✅ Health endpoint returns 200 OK
✅ Chat endpoint accepts requests
✅ Streaming responses appear in UI
✅ Character-by-character typing effect works
✅ No errors in container logs
✅ Authentication works with existing tokens

## Estimated Time

- Infrastructure setup: 5-10 minutes
- Service deployment: 3-5 minutes
- Testing and verification: 5 minutes
- **Total: 15-20 minutes**

## Quick Commands Reference

```bash
# Deploy infrastructure
cd infra/core && terraform apply -var-file=vars/dev.tfvars

# Deploy service
cd services/ai-chat && ./deploy.sh dev

# Check status
az containerapp show --name $(terraform output -raw ai_chat_service_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "properties.{Status:provisioningState,Health:runningStatus}"

# View logs
az containerapp logs show \
  --name $(terraform output -raw ai_chat_service_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --follow

# Get service URL
terraform output ai_chat_service_url
```

## Notes

- Azure OpenAI setup is manual as requested
- Service uses existing authentication infrastructure
- Streaming is configured with Server-Sent Events
- Character typing effect is set to 30ms per character
- Auto-scaling is configured (1-5 replicas)
