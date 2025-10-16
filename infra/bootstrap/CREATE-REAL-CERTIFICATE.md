# Creating SSL Certificate for launchpad.sincs.dev

This guide will help you create a real SSL certificate for your domain `launchpad.sincs.dev` and upload it to the Bootstrap Key Vault.

## Option 1: Let's Encrypt (Recommended - Free & Automated)

Let's Encrypt provides free SSL certificates with 90-day validity and automated renewal.

### Prerequisites
```bash
# Install certbot (macOS)
brew install certbot

# Or using pip
pip install certbot
```

### Step 1: Generate Certificate

You have two methods to verify domain ownership:

#### Method A: DNS Challenge (Recommended for Azure)
Best if you don't have a web server running yet.

```bash
# Generate certificate using DNS challenge
sudo certbot certonly --manual --preferred-challenges dns \
  -d launchpad.sincs.dev

# Certbot will ask you to create a TXT record:
# _acme-challenge.launchpad.sincs.dev = "random-token-here"

# Add this TXT record to your DNS provider (sincs.dev zone)
# Wait for DNS propagation (1-5 minutes)
# Press Enter in certbot to verify

# Certificate will be saved to:
# /etc/letsencrypt/live/launchpad.sincs.dev/fullchain.pem
# /etc/letsencrypt/live/launchpad.sincs.dev/privkey.pem
```

#### Method B: HTTP Challenge
Best if you have a web server accessible at launchpad.sincs.dev:80

```bash
# Generate certificate using HTTP challenge
sudo certbot certonly --standalone \
  -d launchpad.sincs.dev

# This requires port 80 to be open and accessible
```

### Step 2: Convert to PFX Format

Azure Key Vault requires certificates in PFX/PKCS12 format:

```bash
# Convert Let's Encrypt certificate to PFX
sudo openssl pkcs12 -export \
  -out launchpad.sincs.dev.pfx \
  -inkey /etc/letsencrypt/live/launchpad.sincs.dev/privkey.pem \
  -in /etc/letsencrypt/live/launchpad.sincs.dev/fullchain.pem \
  -passout pass:SecurePassword123

# Move to your working directory
sudo cp launchpad.sincs.dev.pfx ~/launchpad.sincs.dev.pfx
sudo chown $(whoami) ~/launchpad.sincs.dev.pfx
```

### Step 3: Upload to Bootstrap Key Vault

```bash
# Navigate to bootstrap directory
cd /Users/bensinclair/projects/starter/infra/bootstrap

# Get Key Vault name
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)
echo "Key Vault: $KEY_VAULT_NAME"

# Upload certificate
az keyvault certificate import \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --file ~/launchpad.sincs.dev.pfx \
  --password "SecurePassword123"

# Verify upload
az keyvault certificate show \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --query "{subject:policy.x509CertificateProperties.subject, expires:attributes.expires}"
```

### Step 4: Update DNS

Point your domain to the Application Gateway public IP:

```bash
# Get Application Gateway IP
cd /Users/bensinclair/projects/starter/infra/core
terraform output app_gateway_public_ip

# Add A record in your DNS:
# launchpad.sincs.dev → [Application Gateway IP]
```

### Step 5: Deploy/Update Infrastructure

```bash
# If not yet deployed
cd /Users/bensinclair/projects/starter/infra/core
terraform init -backend-config=backends/backend-dev.hcl
terraform apply -var-file=vars/dev.tfvars

# If already deployed, just refresh to pick up new certificate
terraform refresh -var-file=vars/dev.tfvars
```

## Option 2: Cloudflare SSL (If using Cloudflare DNS)

If `sincs.dev` is managed by Cloudflare, you can use Cloudflare Origin certificates:

### Step 1: Create Origin Certificate

1. Log into Cloudflare Dashboard
2. Select `sincs.dev` domain
3. Go to SSL/TLS → Origin Server
4. Click "Create Certificate"
5. Set:
   - Hostnames: `launchpad.sincs.dev` or `*.sincs.dev`
   - Key Type: RSA (2048)
   - Certificate Validity: 15 years
6. Click "Create"
7. Save both the certificate and private key

### Step 2: Create PFX File

```bash
# Save certificate to file
cat > launchpad.sincs.dev.crt << 'EOF'
-----BEGIN CERTIFICATE-----
[paste certificate here]
-----END CERTIFICATE-----
EOF

# Save private key to file
cat > launchpad.sincs.dev.key << 'EOF'
-----BEGIN PRIVATE KEY-----
[paste private key here]
-----END PRIVATE KEY-----
EOF

# Convert to PFX
openssl pkcs12 -export \
  -out launchpad.sincs.dev.pfx \
  -inkey launchpad.sincs.dev.key \
  -in launchpad.sincs.dev.crt \
  -passout pass:SecurePassword123
```

### Step 3: Upload to Key Vault

```bash
cd /Users/bensinclair/projects/starter/infra/bootstrap
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)

az keyvault certificate import \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --file launchpad.sincs.dev.pfx \
  --password "SecurePassword123"
```

### Step 4: Configure Cloudflare

1. SSL/TLS mode: **Full (strict)**
2. Add A record: `launchpad` → [Application Gateway IP]
3. Optional: Enable Cloudflare proxy (orange cloud)

## Option 3: Self-Signed Certificate (Development Only)

For development/testing environments:

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 \
  -keyout launchpad.sincs.dev.key \
  -out launchpad.sincs.dev.crt \
  -days 365 \
  -nodes \
  -subj "/CN=launchpad.sincs.dev" \
  -addext "subjectAltName=DNS:launchpad.sincs.dev"

# Convert to PFX
openssl pkcs12 -export \
  -out launchpad.sincs.dev.pfx \
  -inkey launchpad.sincs.dev.key \
  -in launchpad.sincs.dev.crt \
  -passout pass:DevPassword123

# Upload to Key Vault
cd /Users/bensinclair/projects/starter/infra/bootstrap
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)

az keyvault certificate import \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --file launchpad.sincs.dev.pfx \
  --password "DevPassword123"
```

⚠️ **Warning**: Browsers will show security warnings for self-signed certificates.

## Option 4: Azure App Service Certificate

Purchase and manage certificates through Azure:

### Step 1: Purchase Certificate

```bash
# Create App Service Certificate
az appservice certificate create \
  --resource-group rg-terraform-state \
  --name launchpad-sincs-dev-cert \
  --hostname launchpad.sincs.dev \
  --sku Standard

# Follow the domain verification process
```

### Step 2: Import to Key Vault

Azure App Service Certificates can be directly imported to Key Vault through the Azure Portal:

1. Portal → App Service Certificates → Your Certificate
2. Click "Import to Key Vault"
3. Select your bootstrap Key Vault
4. Certificate name: `app-gateway-ssl-cert`

## Verification Steps

After uploading your certificate:

### 1. Check Certificate in Key Vault

```bash
cd /Users/bensinclair/projects/starter/infra/bootstrap
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)

# List certificates
az keyvault certificate list --vault-name $KEY_VAULT_NAME

# Show certificate details
az keyvault certificate show \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --query "{
    name: name,
    subject: policy.x509CertificateProperties.subject,
    sans: policy.x509CertificateProperties.subjectAlternativeNames.dnsNames,
    expires: attributes.expires,
    enabled: attributes.enabled
  }"
```

### 2. Test HTTPS Connection

```bash
# Get Application Gateway IP
cd /Users/bensinclair/projects/starter/infra/core
APP_GW_IP=$(terraform output -raw app_gateway_public_ip)

# Test with curl (add DNS entry or use hosts file)
curl -v https://launchpad.sincs.dev

# Or test with IP and Host header
curl -v https://$APP_GW_IP --resolve launchpad.sincs.dev:443:$APP_GW_IP
```

### 3. Check Certificate in Browser

1. Navigate to `https://launchpad.sincs.dev`
2. Click the padlock icon
3. View certificate details
4. Verify:
   - Subject: CN=launchpad.sincs.dev
   - Issuer: Let's Encrypt or your CA
   - Validity dates
   - SAN includes launchpad.sincs.dev

## Certificate Renewal

### Let's Encrypt Auto-Renewal

```bash
# Test renewal
sudo certbot renew --dry-run

# Actual renewal (when needed)
sudo certbot renew

# After renewal, re-export and upload
sudo openssl pkcs12 -export \
  -out launchpad.sincs.dev-renewed.pfx \
  -inkey /etc/letsencrypt/live/launchpad.sincs.dev/privkey.pem \
  -in /etc/letsencrypt/live/launchpad.sincs.dev/fullchain.pem \
  -passout pass:SecurePassword123

cd /Users/bensinclair/projects/starter/infra/bootstrap
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)

az keyvault certificate import \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --file launchpad.sincs.dev-renewed.pfx \
  --password "SecurePassword123"
```

### Automated Renewal Script

Create a renewal script:

```bash
cat > ~/renew-ssl.sh << 'EOF'
#!/bin/bash
set -e

DOMAIN="launchpad.sincs.dev"
PASSWORD="SecurePassword123"
KV_NAME="kv-bootstrap-xxxxxxxx"  # Update with your Key Vault name

# Renew certificate
sudo certbot renew --quiet

# Convert to PFX
sudo openssl pkcs12 -export \
  -out /tmp/${DOMAIN}.pfx \
  -inkey /etc/letsencrypt/live/${DOMAIN}/privkey.pem \
  -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem \
  -passout pass:${PASSWORD}

# Upload to Key Vault
az keyvault certificate import \
  --vault-name ${KV_NAME} \
  --name app-gateway-ssl-cert \
  --file /tmp/${DOMAIN}.pfx \
  --password "${PASSWORD}"

# Cleanup
sudo rm /tmp/${DOMAIN}.pfx

echo "Certificate renewed and uploaded successfully!"
EOF

chmod +x ~/renew-ssl.sh

# Add to crontab (runs monthly)
# crontab -e
# 0 0 1 * * /Users/bensinclair/renew-ssl.sh >> /var/log/ssl-renewal.log 2>&1
```

## Troubleshooting

### "Certificate not found" Error

```bash
# Verify certificate exists
az keyvault certificate list --vault-name $KEY_VAULT_NAME
```

### "Access Denied" Error

```bash
# Check your permissions
az keyvault show --name $KEY_VAULT_NAME --query properties.accessPolicies
```

### Certificate Import Fails

```bash
# Test PFX file locally
openssl pkcs12 -in launchpad.sincs.dev.pfx -nodes -passin pass:SecurePassword123

# Verify password is correct
openssl pkcs12 -info -in launchpad.sincs.dev.pfx -passin pass:SecurePassword123
```

### DNS Not Resolving

```bash
# Check DNS propagation
dig launchpad.sincs.dev
nslookup launchpad.sincs.dev

# Test with direct IP
curl -k -v https://[APP-GW-IP] --resolve launchpad.sincs.dev:443:[APP-GW-IP]
```

## Security Best Practices

1. **Secure Password**: Use a strong password for PFX files
2. **Delete Local Files**: Remove PFX files after upload
   ```bash
   rm ~/launchpad.sincs.dev.pfx
   rm ~/launchpad.sincs.dev.key
   ```
3. **Monitor Expiry**: Set calendar reminders for renewal (Let's Encrypt: every 60 days)
4. **Use Strong Keys**: Minimum 2048-bit RSA or 256-bit ECDSA
5. **Enable HSTS**: Configure HTTP Strict Transport Security in Application Gateway
6. **Disable Old TLS**: Use TLS 1.2 or higher only

## Recommended: Let's Encrypt with DNS Challenge

**Why?**
- Free and trusted by all browsers
- Automated renewal
- DNS challenge works even if web server isn't running yet
- No port 80 requirement

**Quick Command:**
```bash
sudo certbot certonly --manual --preferred-challenges dns -d launchpad.sincs.dev
sudo openssl pkcs12 -export -out launchpad.sincs.dev.pfx \
  -inkey /etc/letsencrypt/live/launchpad.sincs.dev/privkey.pem \
  -in /etc/letsencrypt/live/launchpad.sincs.dev/fullchain.pem \
  -passout pass:SecurePassword123

cd /Users/bensinclair/projects/starter/infra/bootstrap
az keyvault certificate import \
  --vault-name $(terraform output -raw key_vault_name) \
  --name app-gateway-ssl-cert \
  --file launchpad.sincs.dev.pfx \
  --password "SecurePassword123"
```

Then add DNS TXT record when prompted and you're done! 🎉
