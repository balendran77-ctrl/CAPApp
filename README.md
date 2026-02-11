# CAP App - Complete Stack Project

A full-stack mobile and desktop application with Node.js backend and Flutter frontend.

## Project Structure

```
CAPApp/
├── backend/              # Node.js/Express REST API
│   ├── controllers/      # Business logic
│   ├── models/          # MongoDB schemas
│   ├── routes/          # API endpoints
│   ├── middleware/      # Auth & validation
│   ├── package.json
│   ├── server.js
│   ├── .env.example
│   └── README.md
│
└── mobile/             # Flutter app (Android & Web)
    ├── lib/
    │   ├── main.dart
    │   ├── models/      # Data models
    │   ├── screens/     # UI screens
    │   ├── services/    # API client
    │   └── widgets/     # Reusable widgets
    ├── pubspec.yaml
    ├── android/         # Android-specific config
    ├── web/            # Web-specific config
    └── README.md
```

## Quick Start

### Prerequisites
- **Node.js 16+** and npm
- **Flutter 3.0+** 
- **MongoDB Atlas** account (free tier)
- **Android Studio** or **Xcode** (optional, for emulators)

### 1. Start Backend Server

```bash
cd backend
npm install
cp .env.example .env
# Edit .env and add your MongoDB Atlas credentials
npm run dev
```

Server runs on `http://localhost:5000`

**Test backend:**
```bash
curl http://localhost:5000/api/health
```

### 2. Start Flutter App

```bash
cd mobile
flutter pub get
flutter run
```

**For web:**
```bash
flutter run -d chrome
```

**For Android (emulator or physical device):**
```bash
flutter run -d <device_id>
```

## Features Implemented

### Backend (Node/Express + MongoDB)
- ✅ User Authentication (JWT tokens)
- ✅ User Registration & Login
- ✅ User Profile Management
- ✅ CRUD Operations for Items
- ✅ Soft Delete (archiving items)
- ✅ MongoDB Integration with Mongoose
- ✅ CORS enabled for mobile/web clients
- ✅ Error handling middleware

### Flutter (Mobile & Web)
- ✅ User Authentication Screens (Register/Login)
- ✅ Home Screen with Items List
- ✅ Item Details/Edit Screen
- ✅ Add/Create Item Screen
- ✅ Camera & Gallery Image Picker
- ✅ REST API Client (ApiService)
- ✅ JWT Token Management
- ✅ Material Design UI
- ✅ Responsive Layout

## Environment Setup

### MongoDB Atlas Connection
1. Go to https://www.mongodb.com/cloud/atlas
2. Create a free cluster (M0)
3. Create database user
4. Copy connection string
5. Update `.env` in backend folder:
   ```
   MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/capapp
   ```

### Backend Configuration
Update `backend/.env`:
```
MONGODB_URI=your_connection_string
JWT_SECRET=your_secret_key
PORT=5000
NODE_ENV=development
```

### Flutter Configuration
Update `mobile/lib/services/api_service.dart`:
```dart
// For local development on Android emulator:
static const String baseUrl = 'http://10.0.2.2:5000/api';

// For physical device (replace with your IP):
static const String baseUrl = 'http://192.168.x.x:5000/api';

// For web:
static const String baseUrl = 'http://localhost:5000/api';
```

## API Endpoints

### Authentication
- `POST /api/users/register` - Register new user
- `POST /api/users/login` - Login user
- `GET /api/users/profile` - Get user profile (auth required)
- `PUT /api/users/profile` - Update profile (auth required)

### Items
- `POST /api/items` - Create item (auth required)
- `GET /api/items` - Get all user items (auth required)
- `GET /api/items/:id` - Get item by ID (auth required)
- `PUT /api/items/:id` - Update item (auth required)
- `DELETE /api/items/:id` - Delete/archive item (auth required)

### Health
- `GET /api/health` - Server health check

## Development

### Backend Development
```bash
cd backend
npm run dev      # Starts with nodemon (auto-reload)
```

### Flutter Development
```bash
cd mobile
flutter run      # Hot reload with physical device/emulator
```

### Database
- Access MongoDB Atlas Dashboard: https://cloud.mongodb.com
- View collections, documents, and create indexes

## Building for Production

### Backend Deployment
```bash
# Install dependencies
npm install --production

# Set production environment
NODE_ENV=production
JWT_SECRET=<strong-secret>
MONGODB_URI=<production-uri>

# Run server
node server.js
```

Deployment platforms: Render, Railway, AWS, Heroku, Digital Ocean

### Android App
```bash
# Build APK for testing
flutter build apk

# Build App Bundle for Google Play
flutter build appbundle --release
```

### Web App
```bash
# Build for web deployment
flutter build web --release
```

## Next Steps

### Priority Features
1. **Image Upload Service**
   - Integrate Firebase Storage or AWS S3
   - Replace local image paths with cloud URLs

2. **Push Notifications**
   - Set up Firebase Cloud Messaging (FCM)
   - Handle notification permissions

3. **Offline Data Sync**
   - Add local SQLite database
   - Implement sync logic when online

4. **Advanced Features**
   - User profiles with avatars
   - Item sharing between users
   - Search and filters
   - Item categories and tags
   - User notifications/activity feed

### Security Enhancements
- Add rate limiting to backend
- Implement refresh tokens
- Add input validation/sanitization
- Enable HTTPS in production
- Add CORS configuration
- Implement password reset flow

### Testing
```bash
# Backend unit tests
npm test

# Flutter widget tests
flutter test
```

### Monitoring
- Set up logging (backend: Winston or Bunyan)
- Monitor MongoDB usage and performance
- Track Flutter app crashes/analytics

## Troubleshooting

### Backend issues
- Check MongoDB connection: `mongosh`
- Verify JWT secret is set
- Check CORS is enabled for Flutter app
- View server logs: `npm run dev`

### Flutter issues
- Check API baseUrl configuration
- Verify backend is running
- Clear build: `flutter clean`
- Check Android/iOS permissions
- View device logs: `flutter logs`

### Network issues
- Firewall blocking port 5000
- Mobile device not on same network
- Incorrect API base URL for device type

## Resources

- [Flutter Docs](https://flutter.dev/docs)
- [Node.js & Express](https://expressjs.com/)
- [MongoDB Docs](https://docs.mongodb.com/)
- [Material Design](https://material.io/design)

## Support
For issues or questions:
1. Check README files in `backend/` and `mobile/`
2. Review API documentation above
3. Check Flutter/Node.js logs for errors
4. Run health check: `curl http://localhost:5000/api/health`

---

**Created:** February 9, 2026  
**Stack:** Node.js + Express + MongoDB + Flutter  
**Platforms:** Android, Web
