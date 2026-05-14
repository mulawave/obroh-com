# Obroh.com Architecture & Configuration

## Frontend Origins

### Production
- **Primary Domain**: https://obroh.com
- **Firebase Hosting**: https://obroh.web.app
- **Cloud Run Alternative**: https://obroh-website-134538542038.us-central1.run.app

### Development
- **Local Website**: http://localhost:3000
- **Local Admin**: http://localhost:3001

---

## Backend Origin

### Production
- **Primary**: https://obroh-backend-134538542038.us-central1.run.app
- **Alternative**: https://obroh-backend-zoeqld5lsa-uc.a.run.app

### Development
- **Local Dev**: http://localhost:5000

---

## Express CORS Configuration

### Allowed Origins

```javascript
const allowedOrigins = [
  'https://obroh.com',
  'https://www.obroh.com',
  'https://obroh.web.app',
  'https://admin.obroh.com',
  'https://obroh-website-zoeqld5lsa-uc.a.run.app',
  'https://obroh-admin-zoeqld5lsa-uc.a.run.app',
  'https://obroh-website-134538542038.us-central1.run.app',
];
```

### Implementation (backend/src/server.ts)

```typescript
app.use(cors({
  origin: (origin, callback) => {
    if (!origin) {
      callback(null, true);
      return;
    }

    const configuredOrigins = (process.env.ALLOWED_ORIGINS || "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);

    const allowedOrigins = [
      process.env.WEBSITE_URL || "http://localhost:3000",
      process.env.ADMIN_URL || "http://localhost:3001",
      ...configuredOrigins,
    ];

    if (
      allowedOrigins.includes(origin) ||
      /^http:\/\/localhost:\d+$/.test(origin) ||
      /^http:\/\/127\.0\.0\.1:\d+$/.test(origin)
    ) {
      callback(null, true);
      return;
    }

    callback(new Error(`CORS blocked origin: ${origin}`));
  },
  credentials: true,
}));
```

---

## Authentication Strategy

### JWT (JSON Web Tokens)

**Status**: ✅ **USING JWT** (NOT cookies)

### Details

- **Token Format**: `Authorization: Bearer <token>`
- **Token Expiration**: 7 days
- **Storage** (Web): localStorage with key `auth-token`
- **Storage** (Mobile): Secure storage (flutter_secure_storage)
- **Signing Secret**: `JWT_SECRET` (set in environment variables)

### Cookie Usage

**Status**: ❌ **NOT USING COOKIES**

- No session cookies configured
- No Set-Cookie headers issued
- CORS `credentials: true` is set for future extensibility only
- All communication is stateless and token-based

### Request Example

```typescript
// Web/Mobile request headers
{
  "Authorization": "Bearer eyJhbGciOiJIUzI1NiIs..."
}
```

---

## Environment Variables

**Backend** (`backend/deploy-env.yaml`):
```yaml
WEBSITE_URL: https://obroh.com
ADMIN_URL: https://admin.obroh.com
ALLOWED_ORIGINS: "https://obroh.web.app,https://obroh-website-zoeqld5lsa-uc.a.run.app,..."
JWT_SECRET: obroh-dynasty-secret-key-2024-dev
JWT_EXPIRES_IN: 7d
```

**Website** (`.env.local`):
```
NEXT_PUBLIC_API_URL=/api
```

---

## Summary Table

| Component | Value |
|-----------|-------|
| **Frontend (Web)** | https://obroh.com, http://localhost:3000 |
| **Frontend (Admin)** | https://admin.obroh.com, http://localhost:3001 |
| **Backend** | https://obroh-backend-134538542038.us-central1.run.app |
| **Auth Method** | JWT (Token in Authorization header) |
| **Using Cookies?** | No |
| **CORS Enabled?** | Yes (restrictive allowlist) |
