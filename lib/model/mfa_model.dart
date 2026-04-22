import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents MFA configuration for a user
class MFAConfig {
  final String uid;
  final bool isEnabled;
  final String? secretKey;
  final DateTime createdAt;
  final DateTime? enabledAt;
  final List<String> backupCodes;

  MFAConfig({
    required this.uid,
    required this.isEnabled,
    this.secretKey,
    required this.createdAt,
    this.enabledAt,
    required this.backupCodes,
  });

  factory MFAConfig.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MFAConfig(
      uid: doc.id,
      isEnabled: (data['isEnabled'] ?? false) as bool,
      secretKey: data['secretKey'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      enabledAt: (data['enabledAt'] as Timestamp?)?.toDate(),
      backupCodes: List<String>.from(data['backupCodes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'secretKey': secretKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'enabledAt': enabledAt != null ? Timestamp.fromDate(enabledAt!) : null,
      'backupCodes': backupCodes,
    };
  }

  MFAConfig copyWith({
    String? uid,
    bool? isEnabled,
    String? secretKey,
    DateTime? createdAt,
    DateTime? enabledAt,
    List<String>? backupCodes,
  }) {
    return MFAConfig(
      uid: uid ?? this.uid,
      isEnabled: isEnabled ?? this.isEnabled,
      secretKey: secretKey ?? this.secretKey,
      createdAt: createdAt ?? this.createdAt,
      enabledAt: enabledAt ?? this.enabledAt,
      backupCodes: backupCodes ?? this.backupCodes,
    );
  }
}

/// Represents TOTP secret and configuration
class TOTPSetup {
  final String secret;
  final String otpauthUrl;
  final List<String> backupCodes;

  TOTPSetup({
    required this.secret,
    required this.otpauthUrl,
    required this.backupCodes,
  });
}
