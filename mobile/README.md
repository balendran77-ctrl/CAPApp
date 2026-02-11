# CAP App - Flutter Mobile & Web

Flutter app for Android and Web platforms with REST API integration.

## Features
- User authentication (register/login)
- Create and manage Critical Action Points (CAPs)
- Track CAP status (pending, in-progress, completed)
- Assign CAPs to team members with due dates
- Camera and gallery image capture
- Push notifications support
- Cross-platform (Android & Web)
- Offline-ready architecture

## Prerequisites
- Flutter SDK 3.0+ (https://flutter.dev/docs/get-started/install)
- Android Studio or Xcode (for running on physical devices)
- A running backend server (see `../backend`)

## Setup

### 1. Install Dependencies
```bash
cd mobile
flutter pub get
```

### 2. Connect to Backend
Edit `lib/services/api_service.dart` and update the `baseUrl`:
```dart
static const String baseUrl = 'http://your_server_ip:5000/api';
```

For local development:
- On Android emulator: use `http://10.0.2.2:5000/api`
- On physical device: use your computer's local IP (e.g., `http://192.168.x.x:5000/api`)
- On web: use `http://localhost:5000/api`

### 3. Run the App

**Android:**
```bash
flutter run -d <device_id>
```

**Web:**
```bash
flutter run -d chrome
```

**Web (Release):**
```bash
flutter run -d chrome --release
```

## Project Structure
```
lib/
├── main.dart              # App entry point
├── models/               # Data models (User, Item)
├── screens/              # UI screens
│   ├── auth/            # Login/Register
│   └── home/            # Home, Item details, Add item
├── services/            # API & state management
└── widgets/             # Reusable widgets
```

## API Endpoints
The app communicates with the Node/Express backend. See `../backend/README.md` for all available endpoints.

## Firebase Setup (Push Notifications - Optional)
1. Create a Firebase project at https://console.firebase.google.com
2. Add Android & Web apps
3. Download `google-services.json` and place in `android/app/`
4. Update `.firebaserc` with your project ID

## Building for Production

**Android APK:**
```bash
flutter build apk
```

**Android App Bundle (for Google Play):**
```bash
flutter build appbundle
```

**Web:**
```bash
flutter build web
```

Output will be in `build/` directory.

## Troubleshooting

### Can't connect to backend
- Ensure backend server is running
- Check firewall/network settings
- Verify API base URL in `api_service.dart`
- Check Android permissions in `android/app/AndroidManifest.xml`

### Image picker not working
- Grant camera/gallery permissions in app settings
- On Android, check `android/app/src/main/AndroidManifest.xml` has required permissions

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

## Next Steps
1. Set up Firebase for push notifications
2. Implement image upload to cloud storage
3. Add offline sync with local SQLite database
4. Configure app signing for Google Play/App Store
