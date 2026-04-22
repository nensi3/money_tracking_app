import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:money_tracking_app/model/mfa_model.dart';

class MFAService {
  MFAService._();

  static final MFAService instance = MFAService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _secureStorage = const FlutterSecureStorage();

  static const String _mfaCollectionName = 'mfa_configs';
  static const String _secretPrefix = 'mfa_secret_';
  static const String _jwtTokenKey = 'jwt_token';

  /// Generate a new TOTP secret and setup configuration
  Future<TOTPSetup> generateTOTPSecret({
    required String email,
    required String appName,
  }) async {
    // Generate a secure random secret (base32 encoded)
    final secretBytes = _generateRandomBytes(20);
    final secret = _base32Encode(secretBytes);

    // Generate otpauth URL for QR code
    final otpauthUrl = _generateOtpauthUrl(
      secret: secret,
      email: email,
      issuer: appName,
    );

    // Generate backup codes
    final backupCodes = _generateBackupCodes(8);

    return TOTPSetup(
      secret: secret,
      otpauthUrl: otpauthUrl,
      backupCodes: backupCodes,
    );
  }

  /// Verify OTP code against the secret
  bool verifyOTP({
    required String secret,
    required String code,
    int windowSize = 1,
  }) {
    try {
      final cleanCode = code.replaceAll(' ', '');

      // Generate and verify codes for the time window
      final now = DateTime.now();
      final timeCounter = (now.millisecondsSinceEpoch ~/ 1000) ~/ 30;

      print('ðŸ” MFA Debug - User entered code: $cleanCode');
      print('ðŸ” MFA Debug - Current time counter: $timeCounter');
      print(
        'ðŸ” MFA Debug - Secret (first 8 chars): ${secret.substring(0, 8)}...',
      );

      for (int i = -windowSize; i <= windowSize; i++) {
        final counter = timeCounter + i;
        final generatedCode = _generateTOTP(secret, counter);

        print(
          'ðŸ” MFA Debug - Counter offset: $i, Generated code: $generatedCode',
        );

        if (cleanCode == generatedCode) {
          print('ðŸ” MFA Debug - âœ… CODE MATCH!');
          return true;
        }
      }

      print('ðŸ” MFA Debug - âŒ NO CODE MATCH - All attempts failed');
      return false;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Enable MFA for the current user
  Future<void> enableMFA({
    required String secret,
    required List<String> backupCodes,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final mfaConfig = MFAConfig(
      uid: currentUser.uid,
      isEnabled: true,
      secretKey: secret,
      createdAt: DateTime.now(),
      enabledAt: DateTime.now(),
      backupCodes: backupCodes,
    );

    await _db
        .collection(_mfaCollectionName)
        .doc(currentUser.uid)
        .set(mfaConfig.toMap());

    // Store secret in secure storage
    await _secureStorage.write(
      key: '$_secretPrefix${currentUser.uid}',
      value: secret,
    );
  }

  /// Disable MFA for the current user
  Future<void> disableMFA() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Use set+merge so disable works even if config doc is partially missing.
    await _db.collection(_mfaCollectionName).doc(currentUser.uid).set({
      'isEnabled': false,
      'enabledAt': null,
      'secretKey': null,
      'backupCodes': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _secureStorage.delete(key: '$_secretPrefix${currentUser.uid}');
  }

  /// Get MFA status for a user
  Future<MFAConfig?> getMFAConfig(String uid) async {
    try {
      final doc = await _db.collection(_mfaCollectionName).doc(uid).get();
      if (doc.exists) {
        return MFAConfig.fromDoc(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching MFA config: $e');
      return null;
    }
  }

  /// Get MFA status for the current user
  Future<MFAConfig?> getCurrentUserMFAConfig() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    return getMFAConfig(currentUser.uid);
  }

  /// Check if MFA is enabled for a user
  Future<bool> isMFAEnabled(String uid) async {
    final config = await getMFAConfig(uid);
    return config?.isEnabled ?? false;
  }

  /// Store JWT token securely
  Future<void> storeJWTToken(String token, [String? userId]) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final key = '${_jwtTokenKey}_$uid';
    await _secureStorage.write(key: key, value: token);
  }

  /// Retrieve JWT token from secure storage
  Future<String?> getJWTToken([String? userId]) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return null;

    final key = '${_jwtTokenKey}_$uid';
    return await _secureStorage.read(key: key);
  }

  /// Delete JWT token from secure storage
  Future<void> deleteJWTToken([String? userId]) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return;

    final key = '${_jwtTokenKey}_$uid';
    await _secureStorage.delete(key: key);
  }

  /// Verify backup code and mark it as used
  Future<bool> verifyBackupCode({
    required String uid,
    required String code,
  }) async {
    try {
      final config = await getMFAConfig(uid);
      if (config == null || !config.backupCodes.contains(code)) {
        return false;
      }

      // Remove the used backup code
      final updatedCodes = config.backupCodes.where((c) => c != code).toList();
      await _db.collection(_mfaCollectionName).doc(uid).update({
        'backupCodes': updatedCodes,
      });

      return true;
    } catch (e) {
      print('Error verifying backup code: $e');
      return false;
    }
  }

  /// Get the secret from secure storage
  Future<String?> getStoredSecret(String uid) async {
    return await _secureStorage.read(key: '$_secretPrefix$uid');
  }

  // â”€â”€ PRIVATE HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Generate TOTP code for a given counter value
  String _generateTOTP(String secret, int counter) {
    try {
      // Decode base32 secret to bytes
      final secretBytes = _base32Decode(secret);

      // Create counter bytes (8 bytes, big-endian)
      final counterBytes = ByteData(8);
      counterBytes.setUint64(0, counter, Endian.big);

      // Generate HMAC-SHA1
      final key = secretBytes;
      final message = counterBytes.buffer.asUint8List();
      final hmac = Hmac(sha1, key);
      final digest = hmac.convert(message);
      final digestBytes = digest.bytes;

      // Extract 4-byte code from digest using dynamic binary code
      final offset = digestBytes[digestBytes.length - 1] & 0x0f;
      final code =
          ByteData.view(
            Uint8List.fromList(digestBytes.sublist(offset, offset + 4)).buffer,
          ).getUint32(0, Endian.big) &
          0x7fffffff;

      // Return 6-digit code
      return (code % 1000000).toString().padLeft(6, '0');
    } catch (e) {
      print('Error generating TOTP: $e');
      return '000000';
    }
  }

  /// Decode base32 string to bytes
  List<int> _base32Decode(String input) {
    const String base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final inputUpper = input.replaceAll('=', '').toUpperCase();
    final List<int> bytes = [];
    var buffer = 0;
    var bufferLength = 0;

    for (final char in inputUpper.split('')) {
      final index = base32Alphabet.indexOf(char);
      if (index < 0) continue;

      buffer = (buffer << 5) | index;
      bufferLength += 5;

      if (bufferLength >= 8) {
        bufferLength -= 8;
        bytes.add((buffer >> bufferLength) & 0xff);
      }
    }

    return bytes;
  }

  List<int> _generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String _base32Encode(List<int> bytes) {
    const String base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final StringBuffer result = StringBuffer();

    int bitBuffer = 0;
    int bitBufferLength = 0;

    for (final byte in bytes) {
      bitBuffer = (bitBuffer << 8) | byte;
      bitBufferLength += 8;

      while (bitBufferLength >= 5) {
        bitBufferLength -= 5;
        final index = (bitBuffer >> bitBufferLength) & 0x1F;
        result.write(base32Alphabet[index]);
      }
    }

    if (bitBufferLength > 0) {
      final index = (bitBuffer << (5 - bitBufferLength)) & 0x1F;
      result.write(base32Alphabet[index]);
    }

    return result.toString();
  }

  String _generateOtpauthUrl({
    required String secret,
    required String email,
    required String issuer,
  }) {
    final encodedEmail = Uri.encodeComponent(email);
    final encodedIssuer = Uri.encodeComponent(issuer);

    return 'otpauth://totp/$encodedIssuer:$encodedEmail'
        '?secret=$secret'
        '&issuer=$encodedIssuer'
        '&algorithm=SHA1'
        '&digits=6'
        '&period=30';
  }

  List<String> _generateBackupCodes(int count) {
    final random = Random.secure();
    final codes = <String>[];

    for (int i = 0; i < count; i++) {
      final code = List<int>.generate(8, (_) => random.nextInt(10)).join();
      codes.add(code);
    }

    return codes;
  }
}
