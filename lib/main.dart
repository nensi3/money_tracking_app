import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:money_tracking_app/controller/services/notification_service.dart';

import 'firebase_options.dart';
import 'package:money_tracking_app/view/screens/splashScreen.dart';

Future<void>? _firebaseInitFuture;

FirebaseOptions _resolveFirebaseOptionsSafely() {
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    // Desktop targets can run with web config in local/debug setups.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return DefaultFirebaseOptions.web;
    }
    rethrow;
  }
}

// Serializes Firebase initialization to avoid race conditions that can throw
// [core/duplicate-app] when two async paths try to initialize at once.
Future<void> _initializeFirebaseOnce() async {
  if (Firebase.apps.isNotEmpty) return;

  _firebaseInitFuture ??=
      Firebase.initializeApp(
        options: _resolveFirebaseOptionsSafely(),
      ).then((_) {}).catchError((error) {
        if (error is FirebaseException && error.code == 'duplicate-app') {
          return;
        }
        throw error;
      });

  await _firebaseInitFuture;
}

// Top-level handler required by Firebase Messaging for background events.
// It can run in a separate isolate, so Firebase must be initialized defensively.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebaseOnce();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebaseOnce();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DocumentReference<Map<String, dynamic>> _settingsRef = FirebaseFirestore
      .instance
      .collection('system_settings')
      .doc('global');

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B6EEA)),
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: const Color(0xFF7B6EEA),
    ),
  );

  Widget _buildApp(bool darkModeForced) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Money Tracking App',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: darkModeForced ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _settingsRef.get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final darkModeForced = data['darkModeForced'] == true;
          return _buildApp(darkModeForced);
        },
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _settingsRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final darkModeForced = data['darkModeForced'] == true;
        return _buildApp(darkModeForced);
      },
    );
  }
}
