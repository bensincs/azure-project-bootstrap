package models

import "time"

// User represents an authenticated user from Azure AD JWT
type User struct {
	ID                string    `json:"id"`                // Object ID (oid claim)
	Email             string    `json:"email"`             // Email address (email or preferred_username claim)
	Name              string    `json:"name"`              // Display name (name claim)
	PreferredUsername string    `json:"preferredUsername"` // Preferred username
	TenantID          string    `json:"tenantId"`          // Azure AD tenant ID (tid claim)
	Roles             []string  `json:"roles,omitempty"`   // App roles (roles claim)
	Groups            []string  `json:"groups,omitempty"`  // Group memberships (groups claim)
	IssuedAt          time.Time `json:"issuedAt"`          // Token issued at time
	ExpiresAt         time.Time `json:"expiresAt"`         // Token expiration time
}

// UserClaims represents the JWT claims from Azure AD
type UserClaims struct {
	Oid               string   `json:"oid"`                // Object ID
	Email             string   `json:"email"`              // Email
	PreferredUsername string   `json:"preferred_username"` // Username
	Name              string   `json:"name"`               // Display name
	Tid               string   `json:"tid"`                // Tenant ID
	Roles             []string `json:"roles,omitempty"`    // Application roles
	Groups            []string `json:"groups,omitempty"`   // Group memberships
	Aud               string   `json:"aud"`                // Audience (client ID)
	Iss               string   `json:"iss"`                // Issuer
	Iat               int64    `json:"iat"`                // Issued at
	Exp               int64    `json:"exp"`                // Expiration time
}

// ToUser converts UserClaims to User model
func (uc *UserClaims) ToUser() *User {
	return &User{
		ID:                uc.Oid,
		Email:             uc.Email,
		Name:              uc.Name,
		PreferredUsername: uc.PreferredUsername,
		TenantID:          uc.Tid,
		Roles:             uc.Roles,
		Groups:            uc.Groups,
		IssuedAt:          time.Unix(uc.Iat, 0),
		ExpiresAt:         time.Unix(uc.Exp, 0),
	}
}
