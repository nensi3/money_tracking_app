# MFA Quick Start Guide

## Installation & Setup (5 minutes)

### 1. Install Dependencies

```bash
cd f:\2-mca\flutter\money_tracking_app
flutter pub get
```

### 2. Configure Firestore

- Open Firebase Console
- Go to Firestore Database
- Create collection: `mfa_configs`
- Update security rules (see `FIRESTORE_MFA_SETUP.md`)

### 3. Run the App

```bash
flutter run
```

## User Experience Flow

### Admin User - First Login

```
1. Log in with email/password
2. App detects Admin role
3. MFA setup screen appears
4. Admin installs Google Authenticator
5. Admin scans QR code
6. Admin enters 6-digit verification code
7. Admin saves 8 backup codes
8. Access granted to Admin Dashboard
```

### Admin User - Subsequent Logins

```
1. Log in with email/password
2. App detects Admin role + MFA enabled
3. OTP verification screen appears
4. Admin enters 6-digit code from authenticator
5. Access granted to Admin Dashboard
```

### Non-Admin Users

```
1. Log in normally
2. Directed to HomePage
3. No MFA prompts
```

## Emergency Access - Lost Authenticator

If admin loses access to authenticator:

```
1. Attempt login
2. See "Use backup code instead?" link
3. Enter one of the 8 backup codes
4. Access granted
5. Go to Admin Dashboard → MFA Settings
6. Disable MFA
7. Re-setup with new authenticator on next login
```

## File Reference

### Core Implementation

- `lib/services/mfa_service.dart` - All MFA logic
- `lib/models/mfa_model.dart` - Data structures
- `lib/screens/mfa_setup_screen.dart` - Setup QR code
- `lib/screens/otp_verification_screen.dart` - OTP entry
- `lib/panels/admin_panel/mfa_settings_page.dart` - Settings UI

### Integration Points

- `lib/screens/login_screen.dart` - Routes after login
- `lib/services/auth_service.dart` - Auth service methods
- `lib/panels/admin_panel/admin_panel_screen.dart` - Settings menu

### Configuration

- `pubspec.yaml` - Dependencies
- `FIRESTORE_MFA_SETUP.md` - Firestore rules
- `MFA_IMPLEMENTATION.md` - Full documentation

## Testing Scenarios

### Scenario 1: Fresh Admin Setup

1. Create/login as Admin user
2. Complete MFA setup
3. Save backup codes
4. Logout
5. Login again with OTP
6. Verify Dashboard access

### Scenario 2: Backup Code Recovery

1. Login as Admin
2. Try OTP entry multiple times (fail intentionally)
3. Click "Use backup code instead?"
4. Enter backup code
5. Verify access works

### Scenario 3: Non-Admin Unaffected

1. Create/login as regular User
2. Verify no MFA prompts appear
3. Check all normal functionality works

### Scenario 4: Disable & Re-enable

1. Login as Admin
2. Go to Admin Dashboard → MFA Settings
3. Click "Disable MFA"
4. Logout
5. Login again - should go to setup (not verification)
6. Complete setup again

## Common Issues & Fixes

| Issue                       | Solution                           |
| --------------------------- | ---------------------------------- |
| OTP code won't verify       | Check device time sync with server |
| QR code won't scan          | Use manual secret entry option     |
| Can't find backup codes     | Complete MFA setup again           |
| Logout doesn't work         | Check secure storage permissions   |
| Firestore permission denied | Update security rules per guide    |

## Environment Specifics

### Android

- Secure storage: Uses EncryptedSharedPreferences
- QR camera: Requires camera permission in AndroidManifest.xml
- TOTP: Uses system time

### iOS

- Secure storage: Uses Keychain
- QR camera: Requires camera permission in Info.plist
- TOTP: Uses system time

### Web

- Secure storage: Uses IndexedDB with encryption
- QR generation: Client-side (no camera needed)
- TOTP: Uses device time

## API Integration (Backend)

If using custom backend, implement:

```http
POST /api/mfa/generate-secret
POST /api/mfa/verify-setup
POST /api/mfa/verify-login
DELETE /api/mfa/disable
GET /api/mfa/backup-codes
```

Currently using **Firestore only** - no backend required.

## Security Checklist

- [ ] MFA enabled for all Admin users
- [ ] Firestore rules restrict MFA config access
- [ ] Backup codes saved securely by admins
- [ ] JWT tokens stored in secure storage
- [ ] Device time is synced
- [ ] Authenticator app on trusted device
- [ ] Backup codes kept offline

## Monitoring

### In Firebase Console

```
Firestore → mfa_configs collection
- Monitor document count = number of MFA-enabled admins
- Check for unexpected changes
- Export for backup
```

### In App Logs

```dart
// Check MFA service debug logs
flutter logs | grep "MFA"
```

## Rollback (if needed)

To disable MFA system-wide:

1. Update login_screen.dart - skip MFA check
2. Or delete mfa_configs collection
3. Remove MFA settings menu from admin panel

**Note**: Not recommended in production once users set up MFA.

---

**Quick Links**

- Full Docs: `MFA_IMPLEMENTATION.md`
- Firestore Setup: `FIRESTORE_MFA_SETUP.md`
- Troubleshooting: See full docs
- Questions: Review code comments in `mfa_service.dart`
