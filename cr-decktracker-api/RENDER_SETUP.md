# 🚀 Render.com Deployment Guide

Complete guide to deploy the Clash Royale Deck Tracker API to Render.com.

---

## 📋 Prerequisites

1. **GitHub Account** - Push your code to a GitHub repository
2. **Render.com Account** - Sign up at [render.com](https://render.com)
3. **Supercell API Token** - Get from [developer.clashroyale.com](https://developer.clashroyale.com)

---

## 🔧 Step 1: Create Required Services on Render

### 1.1 Create PostgreSQL Database

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **New** → **PostgreSQL**
3. Configure:
   - **Name**: `cr-decktracker-db`
   - **Database**: `decktracker` (or any name)
   - **User**: `decktracker` (or any name)
   - **Region**: Choose closest to you
   - **Plan**: Free (or Starter $7/month for better performance)
4. Click **Create Database**
5. **Save the Internal Database URL** - You'll need this later
   - Format: `postgresql://user:password@host/database`

### 1.2 Create Redis Instance

1. Click **New** → **Redis**
2. Configure:
   - **Name**: `cr-decktracker-redis`
   - **Region**: Same as PostgreSQL
   - **Plan**: Free
3. Click **Create Redis**
4. **Save the Internal Redis URL** - You'll need this later
   - Format: `redis://red-xxxxx:6379`

---

## 🌐 Step 2: Deploy the Web Service

### 2.1 Create Web Service

1. Click **New** → **Web Service**
2. Connect your GitHub repository
3. Configure:
   - **Name**: `cr-decktracker-api`
   - **Region**: Same as database/redis
   - **Branch**: `main` (or your default branch)
   - **Root Directory**: Leave blank (or specify if API is in subdirectory)
   - **Runtime**: `Python 3`
   - **Build Command**:
     ```bash
     ./build.sh
     ```
   - **Start Command**:
     ```bash
     gunicorn -w 4 -k uvicorn.workers.UvicornWorker app:app --bind 0.0.0.0:$PORT
     ```
   - **Plan**: Free (or upgrade later)

### 2.2 Configure Environment Variables

Click **Advanced** → **Add Environment Variable** and add the following:

| Key | Value | Notes |
|-----|-------|-------|
| `SUPERCELL_API_TOKEN` | `YOUR_TOKEN_HERE` | Get from [developer.clashroyale.com](https://developer.clashroyale.com) |
| `DATABASE_URL` | `postgresql://...` | Copy from PostgreSQL service (Internal URL) |
| `REDIS_URL` | `redis://...` | Copy from Redis service (Internal URL) |
| `JWT_SECRET` | [Generate below] | **IMPORTANT:** Generate a secure secret |
| `ENVIRONMENT` | `production` | Sets production mode |
| `ALLOWED_ORIGINS` | `*` | Allow all origins (or specify your iOS app domain) |
| `PYTHON_VERSION` | `3.11.0` | Specify Python version |

#### Generate JWT_SECRET:

Run this command locally:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Copy the output and paste it as the `JWT_SECRET` value.

**Example output:** `xK8bZ3nR7mQ1pW9yF4tL6vH2sD5jC0aE1qN8gB3hM7u`

---

## 🔄 Step 3: Deploy

1. Click **Create Web Service**
2. Render will automatically:
   - Clone your repository
   - Run `./build.sh` to install dependencies
   - Start the server with gunicorn
3. Wait for deployment (~2-5 minutes)
4. Your API will be live at: `https://your-service-name.onrender.com`

---

## ✅ Step 4: Verify Deployment

### Test Health Endpoint

```bash
curl https://your-service-name.onrender.com/health
```

**Expected response:**
```json
{
  "ok": true,
  "redis": "connected",
  "database": "connected"
}
```

### Test API Endpoints

```bash
# Test player resolution
curl -X POST https://your-service-name.onrender.com/resolve_player \
  -H "Content-Type: application/json" \
  -d '{"player_name": "YourName", "clan_tag": "#ABC123"}'

# Test registration
curl -X POST https://your-service-name.onrender.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "SecurePass123@"}'
```

---

## 📱 Step 5: Update iOS App

Update your iOS app to use the production URL:

### Create Config.swift

```swift
// File: CR DeckTracker/Config.swift
import Foundation

struct AppConfig {
    static let baseURL: String = {
        #if DEBUG
        return "http://127.0.0.1:8001"
        #else
        return "https://your-service-name.onrender.com"
        #endif
    }()
}
```

### Update Service Files

Replace `private let baseURL = "http://127.0.0.1:8001"` with `private let baseURL = AppConfig.baseURL` in:
- `AuthService.swift`
- `APIService.swift`
- `PlayerService.swift`
- `ClanService.swift`

---

## 🔍 Monitoring & Logs

### View Logs

1. Go to your web service dashboard
2. Click **Logs** tab
3. View real-time logs for debugging

### Common Log Messages

- `✅ Connected to Redis` - Redis connected successfully
- `✅ Database tables created successfully` - Database initialized
- `INFO: Started server process` - Gunicorn started
- `INFO: Application startup complete` - App ready

### Monitor Resource Usage

1. Click **Metrics** tab
2. View CPU, memory, and bandwidth usage
3. Upgrade plan if hitting limits

---

## 🛠️ Troubleshooting

### "Missing SUPERCELL_API_TOKEN" Error

- **Cause**: Environment variable not set or invalid
- **Fix**: Check spelling in Render dashboard → Environment tab

### "Could not connect to Redis" Error

- **Cause**: Wrong REDIS_URL or Redis service not running
- **Fix**:
  1. Verify Redis service is running
  2. Use Internal Redis URL (not external)
  3. Format: `redis://red-xxxxx:6379`

### "Database connection failed" Error

- **Cause**: Wrong DATABASE_URL or PostgreSQL not running
- **Fix**:
  1. Verify PostgreSQL service is running
  2. Use Internal Database URL (not external)
  3. Check if URL starts with `postgresql://` (not `postgres://`)

### "Port already in use" Error

- **Cause**: Usually doesn't happen on Render (they manage ports)
- **Fix**: Render automatically assigns `$PORT` - no action needed

### App Slow to Wake Up (Free Tier)

- **Cause**: Render free tier spins down after 15 minutes of inactivity
- **Impact**: First request takes ~30-60 seconds to wake up
- **Fix**:
  - Upgrade to paid plan ($7/month for always-on)
  - Or accept cold start delay on free tier

---

## 🔒 Security Checklist

- [x] JWT_SECRET is randomly generated (not default)
- [x] SUPERCELL_API_TOKEN stored as environment variable
- [x] Database credentials from environment
- [x] HTTPS enabled automatically by Render
- [x] CORS configured (update ALLOWED_ORIGINS for production)
- [x] Rate limiting enabled
- [x] Security headers configured

---

## 💰 Cost Breakdown

| Service | Free Tier | Paid Tier |
|---------|-----------|-----------|
| **Web Service** | 750 hrs/month | $7/month (always-on) |
| **PostgreSQL** | 1 GB storage | $7/month (10 GB) |
| **Redis** | 25 MB | $7/month (100 MB) |
| **Total** | $0/month* | ~$21/month |

*Free tier limitations:
- Web service spins down after 15 min inactivity
- Database limited to 1 GB
- Redis limited to 25 MB

---

## 🎯 Quick Reference

### Essential URLs

- **Render Dashboard**: https://dashboard.render.com
- **Your API**: `https://your-service-name.onrender.com`
- **API Docs**: `https://your-service-name.onrender.com/docs` (Swagger UI)
- **API Health**: `https://your-service-name.onrender.com/health`

### Essential Commands

```bash
# Generate JWT secret
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Test health endpoint
curl https://your-api.onrender.com/health

# View logs locally
render logs -s your-service-name

# Deploy from CLI
render deploy -s your-service-name
```

### Environment Variables Summary

```bash
SUPERCELL_API_TOKEN=eyJ0...  # From developer.clashroyale.com
DATABASE_URL=postgresql://...  # From PostgreSQL service
REDIS_URL=redis://...          # From Redis service
JWT_SECRET=xK8bZ3nR7mQ1...     # Generate with secrets.token_urlsafe(32)
ENVIRONMENT=production
ALLOWED_ORIGINS=*              # Or specific domain
PYTHON_VERSION=3.11.0
```

---

## 📚 Additional Resources

- [Render Python Docs](https://render.com/docs/deploy-python)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Gunicorn Configuration](https://docs.gunicorn.org/en/stable/configure.html)
- [PostgreSQL on Render](https://render.com/docs/databases)
- [Redis on Render](https://render.com/docs/redis)

---

## 🆘 Need Help?

- **Render Support**: https://render.com/docs/support
- **FastAPI Discord**: https://discord.gg/fastapi
- **GitHub Issues**: [Your repo]/issues

---

## ✨ Next Steps After Deployment

1. **Update iOS App** with production URL
2. **Test All Features** end-to-end
3. **Set up Monitoring** (optional: Sentry, LogRocket)
4. **Configure Custom Domain** (optional)
5. **Enable Auto-Deploy** from GitHub (Render does this automatically)
6. **Set up Database Backups** (automatic on paid plan)
7. **Add Health Checks** (Render monitors /health automatically)

---

## 🎉 You're Live!

Your Clash Royale Deck Tracker API is now deployed and ready for production use!

**Your API is accessible at**: `https://your-service-name.onrender.com`

Don't forget to update your iOS app with the production URL and test everything before releasing to TestFlight!
