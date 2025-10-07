# Deploy to Railway.app (FREE)

## Step 1: Install Railway CLI
```bash
npm install -g @railway/cli
```

## Step 2: Prepare backend
```bash
cd backend
railway login
railway init
```

## Step 3: Deploy
```bash
railway up
```

## Step 4: Update Flutter app
After deployment, Railway will give you a URL like:
`https://your-app-name.railway.app`

Update `lib/services/backend_config.dart`:
```dart
static String get base {
  return 'https://your-app-name.railway.app';
}
```

## Alternative: Render.com
1. Go to render.com
2. Connect your GitHub repository  
3. Create new "Web Service"
4. Set build command: `cd backend && pip install -r requirements.txt`
5. Set start command: `cd backend && uvicorn fastapi_app_improved:app --host 0.0.0.0 --port $PORT`

Your backend will be live at: `https://your-service-name.onrender.com`
