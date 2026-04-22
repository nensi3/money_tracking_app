# Multi-Factor Authentication (MFA) Implementation Guide

## Overview

This document describes the Google Authenticator (TOTP) based Multi-Factor Authentication implementation for Admin users in the Money Tracking App. MFA is **only required for Admin role users** and does not affect User or Budget & Report roles.

## Architecture

### Core Components

1. **MFA Service** (`lib/services/mfa_service.dart`)
   - Generates TOTP secrets and otpauth URLs
   - Verifies OTP codes with time-window tolerance
   - Manages MFA configuration in Firestore
   - Securely stores secrets using `flutter_secure_storage`
   - Handles backup codes

2. **MFA Models** (`lib/models/mfa_model.dart`)
   - `MFAConfig`: Firestore document structure for user MFA settings
   - `TOTPSetup`: Data class for TOTP setup (secret, otpauth URL, backup codes)

3. **MFA Setup Screen** (`lib/screens/mfa_setup_screen.dart`)
   - QR code generation using `qr_flutter`
   - Manual secret entry option
   - OTP verification during setup
   - Backup codes display and management

4. **OTP Verification Screen** (`lib/screens/otp_verification_screen.dart`)
   - OTP code input during login
   - Backup code fallback option
   - Real-time verification feedback

5. **MFA Settings Page** (`lib/panels/admin_panel/mfa_settings_page.dart`)
   - MFA status display
   - Enable/Disable MFA
   - Backup codes management
   - FAQ and security information

### Authentication Flow

#### Login Flow for Admin Users

```
1. User enters email & password
2. Firebase authentication succeeds
3. Backend checks if user is Admin
   ├─ If NOT Admin → Direct to HomePage (no MFA required)
   └─ If Admin → Check MFA status
4. Based on MFA status:
   ├─ MFA Enabled → Navigate to OTP Verification Screen
   │  ├─ User enters 6-digit code from authenticator
   │  ├─ Or uses backup code
   │  └─ On success → Admin Dashboard
   └─ MFA Disabled → Navigate to MFA Setup Screen
      ├─ User scans QR code with authenticator
      ├─ Enters verification code
      ├─ Saves backup codes
      └─ On success → Admin Dashboard
```

#### Subsequent Login Flow

```
Email/Password → Admin Check → OTP Verification → Admin Dashboard
```

## Security Features

### 1. TOTP Implementation

- **Algorithm**: SHA-1 based TOTP (RFC 6238)
- **Time step**: 30 seconds
- **Code length**: 6 digits
- **Time window**: ±1 time step (60 seconds total for verification)

### 2. Secure Storage

**JWT Tokens**:

```dart
// Stored key format: jwt_token_<uid>
// Using flutter_secure_storage (platform-specific secure storage)
```

**MFA Secrets**:

```dart
// Stored key format: mfa_secret_<uid>
// Encrypted at rest using platform-specific secure storage
```

### 3. Backup Codes

- 8 generated codes per user
- Each code is 8 digits
- Single-use only (deleted after use)
- Displayed once during MFA setup
- Can be regenerated via disable/re-enable MFA

### 4. Firestore Security

**MFA Config Document** (`mfa_configs/<uid>`):

```json
{
  "isEnabled": boolean,
  "secretKey": string (encrypted at rest by Firestore),
  "createdAt": timestamp,
  "enabledAt": timestamp,
  "backupCodes": [string]
}
```

**Firestore Rules** (recommended):

```
match /mfa_configs/{uid} {
  allow read, write: if request.auth.uid == uid;
}
```

## API Integration

### Backend Endpoints (Example)

```
POST /api/mfa/generate-secret
Response: { secret, otpauthUrl, backupCodes }

POST /api/mfa/verify-setup
Body: { userId, secret, code }
Response: { success, message }

POST /api/mfa/verify-login
Body: { userId, code }
Response: { success, token }

DELETE /api/mfa/disable
Response: { success }

GET /api/mfa/backup-codes
Response: { codes: [string] }
```

## Usage Instructions

### For Admin Users: First Time Setup

1. **Login with email/password**
   - MFA setup screen appears automatically
2. **Setup MFA**
   - Install Google Authenticator (or similar app)
   - Scan the QR code displayed
   - Enter 6-digit code for verification
   - Save backup codes securely
   - Complete setup

3. **Future Logins**
   - Enter email/password
   - Enter OTP code from authenticator
   - Access Admin Dashboard

### For Admin Users: Manage MFA

1. **Access MFA Settings**
   - Admin Dashboard → Management Actions → MFA Settings

2. **View Status**
   - Current MFA status displayed
   - Backup codes available

3. **Disable MFA** (if needed)
   - Click "Disable MFA" button
   - Confirm action
   - MFA disabled on next login

### For Non-Admin Users

- No changes to existing functionality
- Login process unchanged
- No MFA required

## Dependencies

```yaml
dependencies:
  qr_flutter: ^4.1.0 # QR code generation
  flutter_secure_storage: ^9.0.0 # Secure token storage
  totp: ^0.4.0 # TOTP generation & verification
  firebase_core: ^3.0.0 # Firebase
  cloud_firestore: ^5.0.0 # Firestore database
  firebase_auth: ^5.0.0 # Firebase Auth
```

## File Structure

```
lib/
├── models/
│   └── mfa_model.dart              # MFA data models
├── services/
│   ├── mfa_service.dart            # MFA core logic
│   └── auth_service.dart           # Updated for MFA
├── screens/
│   ├── mfa_setup_screen.dart       # Setup screen
│   ├── otp_verification_screen.dart # OTP verification
│   └── login_screen.dart           # Updated for MFA flow
└── panels/admin_panel/
    └── mfa_settings_page.dart      # Admin MFA settings
```

## Key Implementation Details

### MFA Service Methods

```dart
// Generate new TOTP setup
Future<TOTPSetup> generateTOTPSecret({
  required String email,
  required String appName,
})

// Verify OTP code
bool verifyOTP({
  required String secret,
  required String code,
  int windowSize = 1,
})

// Enable MFA
Future<void> enableMFA({
  required String secret,
  required List<String> backupCodes,
})

// Disable MFA
Future<void> disableMFA()

// Check MFA status
Future<bool> isMFAEnabled(String uid)

// JWT Token Management
Future<void> storeJWTToken(String token, [String? userId])
Future<String?> getJWTToken([String? userId])
Future<void> deleteJWTToken([String? userId])

// Backup code verification
Future<bool> verifyBackupCode({
  required String uid,
  required String code,
})
```

### Auth Service Updates

```dart
// Check if user requires MFA
Future<bool> requiresMFAVerification(String uid)

// Get current user
User? getCurrentUser()

// Logout (with JWT cleanup)
Future<void> logout()
```

## Troubleshooting

### OTP Code Not Validating

1. **Check time sync**: Ensure device time is synced with server
2. **Check secret**: Verify secret key is correctly stored
3. **Try backup code**: Use backup code if OTP continues to fail

### MFA Setup Issues

1. **QR code not scanning**
   - Use manual secret entry option
   - Ensure proper lighting and camera focus

2. **Verification fails**
   - Check if device time matches authenticator app
   - Re-enter code slowly to avoid typos

### Lost Access

1. **Lost authenticator device**
   - Use backup code to login
   - Disable/re-enable MFA from settings

2. **No backup codes saved**
   - Contact administrator for account recovery

## Testing Checklist

- [ ] Admin user can setup MFA on first login
- [ ] QR code generation works correctly
- [ ] Manual secret entry option works
- [ ] OTP verification succeeds with valid code
- [ ] OTP verification fails with invalid code
- [ ] Backup codes work as fallback
- [ ] JWT token stored securely
- [ ] Non-admin users unaffected
- [ ] User role unaffected by MFA
- [ ] Budget & Report role unaffected by MFA
- [ ] Disable MFA works correctly
- [ ] Re-enable MFA works correctly
- [ ] Time window tolerance works (±1 time step)

## Best Practices

1. **Always save backup codes** in a secure location
2. **Use time-synced devices** for accurate OTP generation
3. **Never share your secret key** after setup
4. **Disable MFA only when necessary** - it's a critical security feature
5. **Keep authenticator app updated** for best security
6. **Test backup codes** before deleting them

## Future Enhancements

1. **SMS/Email backup codes** instead of display-once
2. **Recovery codes regeneration** without disable/re-enable
3. **FIDO2/WebAuthn support** for hardware keys
4. **Device fingerprinting** for trusted devices
5. **MFA enforcement policies**
6. **Audit logging** for MFA events

## Support

For issues or questions regarding MFA implementation:

1. Check the troubleshooting section above
2. Review the Firebase console for errors
3. Check Firestore `mfa_configs` collection
4. Verify secure storage permissions on device
5. Check Flutter & package versions match requirements

---

**Last Updated**: 2026-04-11
**Status**: Production Ready
