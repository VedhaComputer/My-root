# My Root Frontend 📱💻

Cross-platform client application for the **My Root** community knowledge platform. Built with Flutter 3.x, Dart 3.x, Material 3, Riverpod architecture patterns, and localized into Hindi (`hi`) and English (`en`).

---

## 🏛️ Application Architecture

The Flutter client employs an SPA-style (Single Page Application) in-place view architecture centered around the authenticated user's selected location context:

```
frontend/
├── lib/
│   ├── app/                # App bootstrap, routes, theme
│   ├── core/               # Constants, URL security, failures, localization
│   ├── models/             # Domain models (User, Claim, Place, Evidence, UserActivity)
│   ├── repositories/       # HTTP-backed repositories with strong typing
│   ├── services/           # Service layer with state notifiers:
│   │                       # - AuthService (session lifecycle, secure credentials)
│   │                       # - SecureTokenStorage (FlutterSecureStorage + transparent migration)
│   │                       # - PlaceService (location selection, hierarchy)
│   │                       # - CommunityService (drafts, publications, activity)
│   └── ui/
│       ├── card/           # Reusable cards (ClaimCard, PlaceCard, CommunityProgressCard)
│       ├── pages/          # Pages (HomePage, LoginPage, ProfilePage, PlacesPage, ClaimDetailPage)
│       └── widgets/        # GlobalAppBar, HomeFeaturesDrawer (left), LatestUsersDrawer (right),
│                           # LocationSearchDialog (in-place search & filter)
└── test/                   # 144 unit and widget tests (100% passing)
    ├── flutter_test_config.dart # Global test configuration for storage mocking
    ├── unit/               # Token storage, URL security, auth, claims, lifecycle
    └── widget/             # Profile, Home, Global Header & Sidebars, Modals
```

---

## 🔒 Frontend Security Model

### 1. Secure Token Storage & Transparent Migration (`SecureTokenStorage`)
- **Native Keyring Security**: Tokens (`auth_access_token`, `auth_refresh_token`, `auth_user_data`) are stored securely using platform keystores (Android KeyStore, iOS Keychain, macOS Keychain, Windows Credential Manager, Linux Secret Service).
- **Transparent Migration**: Automatically migrates existing legacy tokens from `SharedPreferences` to `FlutterSecureStorage` upon first launch, then purges the unencrypted legacy keys.
- **Fail-Safe Fallback**: If native keystores are unavailable (e.g. desktop environments without libsecret or test runners), falls back gracefully without crashing.
- **Complete Purge on Sign Out**: Both secure and shared storage partitions are systematically cleared during logout.

### 2. HTTPS Release Enforcement (`sanitizeApiUrl`)
- Enforces strict HTTPS communication in release builds (`kReleaseMode`).
- Plaintext HTTP endpoints or insecure URI schemes (`ftp:`, `javascript:`) throw a runtime `StateError` before any network request is initiated.

### 3. PII & Data Minimization
- Passwords, sensitive credentials, and raw national identity documents are never persisted in local models or client state.
- Public user directory views only render display names and non-sensitive timestamps.

---

## 🧪 Testing & Verification Commands

Execute inside `frontend/`:

```bash
# Verify static analysis (0 warnings, 0 errors)
flutter analyze

# Run all 144 unit and widget tests
flutter test

# Run specific unit test suites
flutter test test/unit/secure_token_storage_test.dart test/unit/url_security_test.dart
flutter test test/unit/auth_service_session_test.dart

# Run widget tests
flutter test test/widget/home_page_test.dart
flutter test test/widget/global_header_and_sidebars_test.dart
flutter test test/widget/profile_page_test.dart
```

---

## 🌐 Running the Application

```bash
# Install dependencies
flutter pub get

# Generate localizations
flutter gen-l10n

# Run on desktop (Windows)
flutter run -d windows

# Run in Chrome (Web)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001
```
