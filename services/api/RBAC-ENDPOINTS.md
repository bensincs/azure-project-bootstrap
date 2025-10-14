# RBAC Endpoints Documentation

This document describes the new RBAC-enabled endpoints in the Hello World API.

## Overview

The API now receives user identity information from Azure AD via APIM headers:
- `X-User-Email` - User's email address
- `X-User-OID` - User's Object ID (unique identifier)
- `X-User-Name` - User's display name
- `X-User-Groups` - JSON array of Azure AD Security Group IDs
- `X-User-Roles` - JSON array of App Role names

## Endpoints

### 1. Get Current User Info

**Endpoint:** `GET /api/user/me`

**Description:** Returns the current authenticated user's information including groups and roles.

**Authentication:** Required (JWT via APIM)

**Response:**
```json
{
  "email": "user@example.com",
  "oid": "12345678-1234-1234-1234-123456789012",
  "name": "John Doe",
  "groups": [
    "87654321-4321-4321-4321-210987654321",
    "11223344-5566-7788-9900-aabbccddeeff"
  ],
  "roles": ["User", "Admin"],
  "groupCount": 2,
  "roleCount": 2,
  "timestamp": "2025-10-14T10:30:00Z"
}
```

**Example:**
```bash
# Via App Gateway public IP
curl -H "Authorization: Bearer <your-jwt-token>" \
  https://<app-gateway-ip>/api/user/me

# Testing locally with mock headers
curl -H "X-User-Email: test@example.com" \
     -H "X-User-Name: Test User" \
     -H "X-User-Groups: [\"group1\",\"group2\"]" \
     -H "X-User-Roles: [\"Admin\",\"User\"]" \
     http://localhost:8080/api/user/me
```

### 2. Admin Test Endpoint

**Endpoint:** `GET /api/admin/test`

**Description:** Example of role-based authorization - only users with "Admin" role can access.

**Authentication:** Required (JWT via APIM)

**Authorization:** Requires `Admin` role

**Success Response (200):**
```json
{
  "message": "Welcome, Admin John Doe!",
  "adminFeatures": [
    "User Management",
    "System Configuration",
    "Audit Logs",
    "Advanced Analytics"
  ],
  "timestamp": "2025-10-14T10:30:00Z"
}
```

**Forbidden Response (403):**
```json
{
  "error": "Forbidden",
  "message": "This endpoint requires Admin role"
}
```

**Example:**
```bash
# User with Admin role - succeeds
curl -H "Authorization: Bearer <admin-jwt-token>" \
  https://<app-gateway-ip>/api/admin/test

# User without Admin role - returns 403
curl -H "Authorization: Bearer <user-jwt-token>" \
  https://<app-gateway-ip>/api/admin/test

# Testing locally with mock headers
curl -H "X-User-Name: Admin User" \
     -H "X-User-Roles: [\"Admin\"]" \
     http://localhost:8080/api/admin/test
```

## Implementation Details

### Parsing Headers

The API parses APIM headers in two ways:

1. **JSON format** (preferred): `["item1", "item2"]`
2. **Comma-separated** (fallback): `item1, item2`

```csharp
// Parse groups/roles
string[]? roles = null;
try
{
    if (!string.IsNullOrEmpty(rolesHeader))
    {
        roles = JsonSerializer.Deserialize<string[]>(rolesHeader);
    }
}
catch
{
    roles = rolesHeader?.Split(',',
        StringSplitOptions.RemoveEmptyEntries |
        StringSplitOptions.TrimEntries);
}
```

### Role-Based Authorization Example

```csharp
app.MapGet("/api/admin/test", (HttpContext context) =>
{
    var rolesHeader = context.Request.Headers["X-User-Roles"].FirstOrDefault();

    string[]? roles = null;
    // ... parse roles ...

    var isAdmin = roles?.Contains("Admin", StringComparer.OrdinalIgnoreCase) ?? false;

    if (!isAdmin)
    {
        return Results.Json(
            new { error = "Forbidden", message = "Admin role required" },
            statusCode: 403
        );
    }

    // Admin-only logic here
    return Results.Ok(new { message = "Admin access granted" });
});
```

## Setting Up RBAC

### Option 1: Azure AD Security Groups

1. **Create Security Groups** in Azure AD:
   ```bash
   az ad group create --display-name "app-admins" --mail-nickname "app-admins"
   az ad group create --display-name "app-users" --mail-nickname "app-users"
   ```

2. **Add users to groups**:
   ```bash
   az ad group member add --group "app-admins" --member-id <user-oid>
   ```

3. **Map Group IDs** in your code:
   ```csharp
   var groupMapping = new Dictionary<string, string> {
       { "12345678-...", "app-admins" },
       { "87654321-...", "app-users" }
   };

   var isAdmin = groups?.Any(g =>
       groupMapping.GetValueOrDefault(g) == "app-admins") ?? false;
   ```

### Option 2: Azure AD App Roles (Recommended)

1. **Add App Roles** in `azure-ad.tf`:
   ```terraform
   app_role {
     allowed_member_types = ["User"]
     description          = "Admin users"
     display_name         = "Admin"
     enabled              = true
     id                   = "00000000-0000-0000-0000-000000000001"
     value                = "Admin"
   }
   ```

2. **Assign roles** via Azure Portal:
   - Azure AD → Enterprise Applications → Your App
   - Users and Groups → Add user/group
   - Select role

3. **Use role names directly**:
   ```csharp
   var isAdmin = roles?.Contains("Admin") ?? false;
   ```

## Testing Locally

When testing locally without APIM, you can mock the headers:

```bash
# Test user info endpoint
curl -H "X-User-Email: test@example.com" \
     -H "X-User-Name: Test User" \
     -H "X-User-OID: 12345678-1234-1234-1234-123456789012" \
     -H "X-User-Groups: [\"group1\"]" \
     -H "X-User-Roles: [\"User\"]" \
     http://localhost:8080/api/user/me

# Test admin endpoint (should succeed)
curl -H "X-User-Name: Admin User" \
     -H "X-User-Roles: [\"Admin\"]" \
     http://localhost:8080/api/admin/test

# Test admin endpoint (should return 403)
curl -H "X-User-Name: Regular User" \
     -H "X-User-Roles: [\"User\"]" \
     http://localhost:8080/api/admin/test
```

## Deployment

After updating the code:

```bash
cd services/api
./deploy.sh
```

This will:
1. Build the Docker image
2. Push to Azure Container Registry
3. Update the Container App with the new image

## Security Notes

1. **Trust APIM Headers**: Since APIM validates the JWT before forwarding, you can trust the `X-User-*` headers
2. **No Direct Access**: Container Apps are private - only accessible via APIM
3. **Audit Logging**: Consider logging role-based actions for compliance
4. **Principle of Least Privilege**: Assign minimum necessary roles

## Resources

- [Azure AD App Roles](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps)
- [Azure AD Group Claims](https://learn.microsoft.com/en-us/azure/active-directory/develop/optional-claims)
- [APIM Policy Reference](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
