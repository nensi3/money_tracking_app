import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _channelId = 'transaction_updates';
  static const String _channelName = 'Transaction Updates';
  static const String _channelDesc =
      'Notifications for transaction approvals and rejections';

  bool _initialized = false;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  Future<void> init({String? userId}) async {
    // Firebase must be initialized once in main.dart. Re-initializing here
    // can cause [core/duplicate-app], so we only validate the precondition.
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase is not initialized. Call Firebase.initializeApp() in main() first.',
      );
    }

    if (_initialized) {
      if (userId != null) {
        await syncUserToken(userId);
      }
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messageSubscription ??= FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      final notification = message.notification;
      if (notification == null) return;
      await showLocalNotification(
        title: notification.title ?? 'Money Tracking App',
        body: notification.body ?? '',
      );
    });

    _tokenSubscription ??= _messaging.onTokenRefresh.listen((token) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        unawaited(_storeTokenSafely(currentUser.uid, token));
      }
    });

    _initialized = true;

    if (userId != null) {
      await syncUserToken(userId);
    }
  }

  Future<void> syncCurrentUserToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await syncUserToken(currentUser.uid);
  }

  Future<void> syncUserToken(String userId) async {
    try {
      await init();

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _storeTokenSafely(userId, token);
      }

      await _messaging.subscribeToTopic(_topicForUser(userId));
    } catch (e) {
      print('⚠️ Token sync skipped: $e');
    }
  }

  Future<void> saveNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (data != null) ...data,
    });
  }

  Future<void> sendTransactionUpdateNotification({
    required String userId,
    required String title,
    required String message,
    required String transactionId,
    required String status,
    String? rejectionReason,
  }) async {
    // Save notification to Firestore (best effort, doesn't block transaction)
    _saveNotificationAsync(
      userId: userId,
      title: title,
      message: message,
      transactionId: transactionId,
      status: status,
      rejectionReason: rejectionReason,
    );

    // Show local notification (best effort, doesn't block transaction)
    _showLocalNotificationAsync(title: title, body: message);
  }

  /// Saves notification asynchronously without blocking the caller.
  void _saveNotificationAsync({
    required String userId,
    required String title,
    required String message,
    required String transactionId,
    required String status,
    String? rejectionReason,
  }) {
    // Fire and forget - use Future.microtask to run in next event loop
    Future.microtask(() async {
      try {
        if (userId.trim().isEmpty) {
          print('⚠️ Cannot save notification: empty userId');
          return;
        }

        await saveNotification(
          userId: userId,
          title: title,
          message: message,
          data: {
            'transactionId': transactionId,
            'status': status,
            'type': 'transaction_status',
            if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
              'rejectionReason': rejectionReason.trim(),
          },
        ).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            print('⚠️ Notification save timed out after 8s');
            throw TimeoutException('Notification save timeout');
          },
        );
        print('✅ Notification saved for user: $userId');
      } on TimeoutException catch (e) {
        print('❌ Notification save timeout: $e');
      } catch (e) {
        print('❌ Failed to save notification: $e');
      }
    });
  }

  /// Shows local notification asynchronously without blocking the caller.
  void _showLocalNotificationAsync({
    required String title,
    required String body,
  }) {
    // Fire and forget - use Future.microtask to run in next event loop
    Future.microtask(() async {
      try {
        await showLocalNotification(title: title, body: body).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Local notification timed out after 5s');
            throw TimeoutException('Local notification timeout');
          },
        );
        print('✅ Local notification shown: $title');
      } on TimeoutException catch (e) {
        print('❌ Local notification timeout: $e');
      } catch (e) {
        print('❌ Failed to show local notification: $e');
      }
    });
  }

  Future<void> showBudgetAlert({
    required String title,
    required String body,
  }) async {
    await showLocalNotification(title: title, body: body);
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> _storeTokenSafely(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      print('⚠️ Skipping FCM token sync: ${e.code}');
    } catch (e) {
      print('⚠️ Skipping FCM token sync: $e');
    }
  }

  String _topicForUser(String userId) => 'user_$userId';
}
