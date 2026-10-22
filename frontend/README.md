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

---

## 🚀 Production Release Build & Hardening

Release builds must be compiled with Dart identifier obfuscation and separated debug symbols.

### 1. Build Commands with Obfuscation & Split Debug Info
Run inside `frontend/`:

```bash
# Production Android APK (requires configured key.properties or signing env vars; fails closed otherwise)
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Non-Production Local Verification Build (explicitly permitted debug-key signing)
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols -PallowLocalDebugSigning=true

# Production Android App Bundle (Google Play deployment)
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Windows Desktop Release
flutter build windows --release --obfuscate --split-debug-info=build/windows/outputs/symbols

# iOS Archive (requires macOS host and Xcode toolchain)
flutter build ipa --release --obfuscate --split-debug-info=build/ios/outputs/symbols
```

Alternatively, use the standardized release scripts:
```powershell
# Production build (fails closed if signing credentials are unconfigured)
.\scripts\build_release.ps1 -Target apk -SymbolsDir build/app/outputs/symbols

# Production CI build (strictly prohibits any debug signing override)
.\scripts\build_release.ps1 -Target apk -SymbolsDir build/app/outputs/symbols -EnforceProductionSigning

# Non-production local testing build (explicitly permits debug signing)
.\scripts\build_release.ps1 -Target apk -SymbolsDir build/app/outputs/symbols -AllowLocalDebugSigning
```
```bash
# Production build
./scripts/build_release.sh apk build/app/outputs/symbols

# Production CI build (strictly prohibits any debug signing override)
ENFORCE_PRODUCTION_SIGNING=true ./scripts/build_release.sh apk build/app/outputs/symbols

# Non-production local testing build
./scripts/build_release.sh apk build/app/outputs/symbols true
```

### 2. Android Fail-Safe Signing & R8 Minification
- `android/app/build.gradle.kts` enforces **fail-safe release signing**:
  - Production release builds require explicitly configured release signing credentials via `android/key.properties` (or environment variables `MYROOT_KEYSTORE_PATH`, `MYROOT_KEYSTORE_PASSWORD`, `MYROOT_KEY_ALIAS`, `MYROOT_KEY_PASSWORD`).
  - If production credentials are missing or invalid, the build fails closed with an explicit `PRODUCTION SIGNING REQUIRED` error. It will **never silently fall back to debug signing**.
  - Local verification builds using debug-key signing are permitted **only** when explicitly requested via `-PallowLocalDebugSigning=true` (or `-AllowLocalDebugSigning` in the script) and are prominently labeled as non-production.
  - Keystores (`*.jks`, `*.keystore`) and credentials files (`key.properties`) are strictly excluded by `.gitignore` and must never be committed to version control.
- R8 minification and resource shrinking are enabled for `release` (`isMinifyEnabled = true`, `isShrinkResources = true`).
- Keep rules in `android/app/proguard-rules.pro` are kept minimal, preserving line number tables and annotations (`-keepattributes *Annotation*, SourceFile, LineNumberTable`) required for crash de-obfuscation without overly broad wildcard rules.

### 3. Debug Symbol & R8 Mapping Retention
- **Dual Artifact Separation**:
  1. **Dart Program Symbols**: Output to `build/app/outputs/symbols/` (`app.<arch>.symbols`).
  2. **Android R8 Mapping Files**: Output to `build/app/outputs/mapping/release/` (`mapping.txt`, `seeds.txt`, `usage.txt`, `configuration.txt`).
- Both directories and their outputs are excluded from Git via `.gitignore`.
- **Operational Responsibility**: Because obfuscated binaries replace human-readable identifiers with randomized symbols, operators **must privately archive and back up** both the Dart symbol directory and the Android R8 `mapping.txt` file for every production release using access-controlled cold storage (such as private AWS S3 / Google Cloud Storage buckets).
- *Implementation Status*: Remote archival is **not implemented** in this local repository; establishing an automated upload pipeline to an external, access-controlled vault is the operator's responsibility during CI/CD infrastructure provisioning.
- To de-obfuscate a Dart stack trace from an obfuscated build:
```bash
flutter symbolize -i <obfuscated_stack_trace.txt> -d build/app/outputs/symbols
```
