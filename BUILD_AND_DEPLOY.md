# CAP App - Build & Deployment Guide

Complete guide for building and deploying CAP App to Android (Google Play), web (static hosting), and desktop.

## Prerequisites

- **Backend deployed** (Node.js server running on a domain/server)
- **Flutter SDK installed** (3.0+)
- **Android Studio** (for Android builds)
- **Signing key** (for Google Play releases)

---

## 1. Backend Deployment

### Option A: Deploy to Render (Free, recommended for testing)

```bash
cd backend
npm install
```

1. Go to https://render.com
2. Click **New** → **Web Service**
3. Connect your GitHub repo (or manual deploy)
4. **Environment:** Node
5. **Build command:** `npm install`
6. **Start command:** `node server.js`
7. Add environment variables:
   - `MONGODB_URI=mongodb+srv://...`
   - `JWT_SECRET=<strong-secret>`
   - `NODE_ENV=production`
8. Deploy

Backend will be available at `https://capapp-backend.onrender.com`

### Option B: Deploy to AWS, Heroku, DigitalOcean, Railway, or Fly.io

Update backend README for your chosen platform.

### Option C: Deploy to your own server

```bash
ssh user@your-server
cd /var/www/capapp-backend
git pull
npm install --production
NODE_ENV=production node server.js  # use PM2, systemd, or nginx reverse proxy
```

---

## 2. Flutter Mobile App (Android)

### 2.1 Update API Base URL

Replace backend URL in [mobile/lib/services/api_service.dart](mobile/lib/services/api_service.dart):

```dart
static const String baseUrl = 'https://capapp-backend.onrender.com/api';  // Use your deployed backend
```

### 2.2 Configure App Metadata

Edit [mobile/pubspec.yaml](mobile/pubspec.yaml):
```yaml
name: capapp
description: CAP App - Organize and manage your items
version: 1.0.0+1
```

Edit [mobile/android/app/build.gradle](mobile/android/app/build.gradle):
```gradle
android {
    compileSdkVersion 33
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
        applicationId "com.capapp.mobile"
        versionCode 1
        versionName "1.0.0"
    }
}
```

### 2.3 Build APK (Debug)

```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --debug
```

Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`

Install on device:
```bash
flutter install
# or: adb install mobile/build/app/outputs/flutter-apk/app-debug.apk
```

### 2.4 Build APK (Release)

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`

### 2.5 Build App Bundle (for Google Play Store)

```bash
flutter build appbundle --release
```

Output: `mobile/build/app/outputs/bundle/release/app-release.aab`

#### Generate Signing Key (one-time)

```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store the key in a safe place. You'll need it for Google Play uploads.

#### Configure Signing

Edit [mobile/android/app/build.gradle](mobile/android/app/build.gradle):

```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias System.getenv("KEY_ALIAS") ?: "upload"
            keyPassword System.getenv("KEY_PASSWORD") ?: "your_password"
            storeFile file(System.getenv("KEYSTORE_PATH") ?: "../keystore.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD") ?: "your_password"
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

Or set environment variables before building:

```bash
export KEY_ALIAS=upload
export KEY_PASSWORD=your_password
export KEYSTORE_PATH=/path/to/key.jks
export KEYSTORE_PASSWORD=your_password
flutter build appbundle --release
```

### 2.6 Upload to Google Play Store

1. Create developer account: https://play.google.com/console
2. Create new app (name: "CAP App")
3. Upload App Bundle:
   - **Release** → **Production** → Click **Upload**
   - Select `mobile/build/app/outputs/bundle/release/app-release.aab`
4. Fill in app details:
   - Screenshots (required: 3-5)
   - Description
   - Privacy policy
   - Category
5. Content rating (IARC questionnaire)
6. Target audience
7. Pricing (Free)
8. Release → Review and publish

**Timeline:** 2-4 hours for initial review, then live on Play Store.

---

## 3. Flutter Web

### 3.1 Update API Base URL

Same as Android — update [mobile/lib/services/api_service.dart](mobile/lib/services/api_service.dart):

```dart
static const String baseUrl = 'https://capapp-backend.onrender.com/api';
```

### 3.2 Build Web

```bash
cd mobile
flutter clean
flutter pub get
flutter build web --release
```

Output: `mobile/build/web/`

### 3.3 Deploy Web to Static Hosting

#### Option A: Netlify (Free, recommended)

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
cd mobile
netlify deploy --prod --dir build/web
```

Or connect your GitHub repo to Netlify UI for auto-deploy on every push.

#### Option B: Vercel

```bash
npm install -g vercel
cd mobile
vercel --prod
```

#### Option C: Firebase Hosting

```bash
npm install -g firebase-tools
firebase login
firebase init hosting
# Select mobile/build/web as public directory
firebase deploy
```

#### Option D: GitHub Pages (Free, works for project repos)

Edit [mobile/pubspec.yaml](mobile/pubspec.yaml) - add web asset path if needed:

```bash
cd mobile/build/web
# Commit and push to gh-pages branch
```

Configure GitHub Pages in repo settings → Pages → Deploy from gh-pages branch.

#### Option E: AWS S3 + CloudFront

```bash
aws s3 sync mobile/build/web s3://capapp-web/
```

---

## 4. Push Notifications (Firebase Cloud Messaging)

To enable push notifications in both Android and Web:

### 4.1 Set up Firebase Project

1. Go to https://console.firebase.google.com
2. Create new project: "CAP App"
3. Add Android app: `com.capapp.mobile`
4. Download `google-services.json` → place in `mobile/android/app/`
5. Add Web app and get config
6. Update `mobile/lib/main.dart` with Firebase initialization

### 4.2 Configure FCM Backend

Update `backend/.env`:
```
FCM_PROJECT_ID=your-project-id
FCM_PRIVATE_KEY=your_private_key
FCM_CLIENT_EMAIL=your_email@...iam.gserviceaccount.com
```

### 4.3 Send Push from Backend

Example endpoint in `backend/routes/users.js`:

```javascript
const admin = require('firebase-admin');

app.post('/api/notifications/send', async (req, res) => {
  try {
    const { userId, title, body } = req.body;
    
    await admin.messaging().sendToDevice(fcmToken, {
      notification: { title, body },
      data: { action: 'view_item' }
    });
    
    res.json({ message: 'Notification sent' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

---

## 5. Versioning & Release Management

### Version Bumping

Update version in:
- `mobile/pubspec.yaml` (e.g., `1.0.0+1` → `1.0.1+2`)
- `backend/package.json` (e.g., `1.0.0` → `1.0.1`)
- Git tag: `git tag v1.0.1`

### Release Notes

Create `CHANGELOG.md`:

```markdown
## [1.0.1] - 2026-02-09
### Added
- Camera image picker for items

### Fixed
- MongoDB connection error on startup

### Changed
- Updated API base URL to production server
```

---

## 6. Monitoring & Logging

### Backend Logging

Add to `backend/server.js`:

```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

mongoose.connect(process.env.MONGODB_URI)
  .then(() => logger.info('MongoDB connected'))
  .catch(err => logger.error('MongoDB error:', err));
```

### Analytics (Mobile)

Add Firebase Analytics to `mobile/lib/main.dart`:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// Track screen view
await analytics.logScreenView(screenName: 'home_screen');

// Track event
await analytics.logEvent(
  name: 'item_created',
  parameters: { 'category': 'test' }
);
```

---

## 7. Security Checklist

- [ ] Backend: Set `NODE_ENV=production`
- [ ] Backend: Use strong `JWT_SECRET` (32+ random chars)
- [ ] Backend: Enable CORS only for your frontend domain
- [ ] Backend: Rate limit API endpoints
- [ ] App: Don't hardcode API keys/secrets
- [ ] App: Use HTTPS for all API calls (already configured for `https://`)
- [ ] Database: Enable IP whitelist in MongoDB Atlas
- [ ] Database: Create separate DB user for production
- [ ] API: Implement request validation & sanitization
- [ ] App: Handle sensitive data (passwords, tokens) securely

---

## 8. Troubleshooting

### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --verbose  # see detailed errors
```

### API Connection Issues

Check:
1. Backend is deployed and running
2. API base URL in `api_service.dart` is correct
3. CORS is enabled in backend
4. Firewall isn't blocking requests
5. Network connectivity on device/emulator

### Google Play Upload Errors

- App Bundle must be signed with release key
- Version code must be higher than previous
- Screenshots must meet size requirements
- Privacy policy URL required

---

## 9. Performance Optimization

### Flutter App

```bash
# Profile build
flutter run --profile

# Release build optimizations
flutter build apk --split-per-abi  # smaller APKs per architecture
flutter build appbundle --release  # use App Bundle for Play Store
```

### Backend

```bash
# Enable compression
npm install compression
// In server.js:
const compression = require('compression');
app.use(compression());
```

---

## Next Steps

1. **Deploy backend** to your chosen platform
2. **Update API base URL** in Flutter app
3. **Build & test** APK on Android device
4. **Build & deploy** web version
5. **Set up Firebase** for push notifications
6. **Submit to Google Play** when ready for production

---

## Resources

- [Flutter Deploy](https://flutter.dev/docs/deployment)
- [Google Play Console](https://play.google.com/console)
- [Render Deployment](https://render.com/docs)
- [Firebase Setup](https://firebase.google.com/docs)
- [Node.js Deployment](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)

