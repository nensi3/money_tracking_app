# Firestore Setup for MFA

## Required Collection

Add the following collection to your Firestore database:

```
Collection: mfa_configs
```

## Document Structure

Each document is keyed by user UID:

```
mfa_configs
├── <user_uid_1>
│   ├── isEnabled: boolean (default: false)
│   ├── secretKey: string (encrypted at rest)
│   ├── createdAt: timestamp
│   ├── enabledAt: timestamp (null if disabled)
│   └── backupCodes: array of strings (8 zero-use codes)
├── <user_uid_2>
│   └── ...
```

## Example Document

```json
{
  "isEnabled": true,
  "secretKey": "JBSWY3DPEBLW64TMMQ======",
  "createdAt": Timestamp("2026-04-11T10:30:00Z"),
  "enabledAt": Timestamp("2026-04-11T10:35:45Z"),
  "backupCodes": [
    "12345678",
    "87654321",
    "11111111",
    "22222222",
    "33333333",
    "44444444",
    "55555555",
    "66666666"
  ]
}
```

## Firestore Security Rules

Add these rules to your Firestore to secure MFA configurations:

```firestore
// Firestore Rules
match /mfa_configs/{uid} {
  // Only the user themselves can read/write their MFA config
  allow read, write: if request.auth.uid == uid;

  // Deny all other access
  allow read, write: if false;
}
```

## Complete Firestore Rules Example

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // MFA Configurations - User-specific access only
    match /mfa_configs/{uid} {
      allow read, write: if request.auth.uid == uid;
    }

    // Users Collection - Existing rules
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if request.auth.uid == uid;
      allow read, write: if isAdmin(request.auth.uid);
    }

    // Transactions Collection - Existing rules
    match /transactions/{transactionId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
    }

    // Categories Collection
    match /categories/{categoryId} {
      allow read, write: if request.auth.uid != null;
    }

    // Helper function to check admin status
    function isAdmin(uid) {
      return exists(/databases/$(database)/documents/users/$(uid))
        && get(/databases/$(database)/documents/users/$(uid)).data.role == 'Admin';
    }
  }
}
```

## Implementation Steps

1. **Open Firebase Console**
   - Go to your project
   - Navigate to Firestore Database

2. **Create Collection**
   - Click "Start collection"
   - Name: `mfa_configs`
   - Click "Next"
   - Skip document creation (documents will be created by app)
   - Click "Save"

3. **Update Security Rules**
   - Go to "Rules" tab
   - Replace existing rules with the rules above
   - Click "Publish"

4. **Verify Setup**
   - Run your Flutter app
   - Admin user setup MFA
   - Check Firestore console
   - Verify `mfa_configs/<uid>` document exists

## Testing the Setup

### Create Test MFA Config

```javascript
// Run in Firebase Console -> Firestore -> Shell
db.collection("mfa_configs").doc("test_user_id").set({
  isEnabled: false,
  secretKey: "JBSWY3DPEBLW64TMMQ======",
  createdAt: new Date(),
  enabledAt: null,
  backupCodes: [],
});
```

### Verify Rules

```javascript
// This should succeed (authenticated user reads own doc)
db.collection("mfa_configs").doc("current_user_id").get();

// This should fail (unauthorized access)
db.collection("mfa_configs").doc("other_user_id").get();
```

## Backup Strategy

### Daily Backups

Enable automatic backups in Firebase Console:

1. Go to Firestore Database
2. Click "Backups"
3. Click "Create Backups"
4. Select `mfa_configs` collection
5. Set daily schedule
6. Retention: 7 days minimum

### Manual Export

```bash
# Example using gcloud CLI
gcloud firestore export gs://your-bucket/mfa-backup-$(date +%s) \
  --collection-ids=mfa_configs
```

## Migration Guide

If migrating from non-MFA setup:

1. **No immediate action needed** - collection auto-created on first MFA setup
2. **Run migration script** (optional):

```dart
// One-time migration to pre-create MFA configs for admins
Future<void> initializeMFAForExistingAdmins() async {
  final db = FirebaseFirestore.instance;
  final adminUsers = await db
      .collection('users')
      .where('role', isEqualTo: 'Admin')
      .get();

  for (var doc in adminUsers.docs) {
    final existingMFA = await db
        .collection('mfa_configs')
        .doc(doc.id)
        .get();

    if (!existingMFA.exists) {
      await db.collection('mfa_configs').doc(doc.id).set({
        'isEnabled': false,
        'secretKey': null,
        'createdAt': DateTime.now(),
        'enabledAt': null,
        'backupCodes': [],
      });
    }
  }
}
```

## Troubleshooting

### MFA Config Not Saving

**Issue**: MFA setup completes but config not saved to Firestore

**Solution**:

1. Check Firestore security rules
2. Verify user is authenticated
3. Check Firebase console logs for errors
4. Ensure `mfa_configs` collection exists

### Cannot Read MFA Config

**Issue**: Login fails because MFA config can't be read

**Solution**:

1. Verify security rules allow user access
2. Check user UID is correct
3. Verify Firestore is initialized
4. Check internet connectivity

### Backup Codes Not Updating

**Issue**: Used backup codes still appear as available

**Solution**:

1. Check Firestore write permissions
2. Verify batch write succeeds
3. Check for race conditions in concurrent logins

## Monitoring

### Enable Audit Logging

```firestore
// In Firebase Console -> Audit Logs
// Filter by service: Cloud Firestore
// Filter by collection: mfa_configs
```

### Monitor Collection Growth

```javascript
// Watch collection size
db.collection("mfa_configs").onSnapshot((snapshot) => {
  console.log("MFA Configs:", snapshot.size);
});
```

---

**Last Updated**: 2026-04-11
