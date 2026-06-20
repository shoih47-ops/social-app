import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/fcm_service.dart';
import 'services/share_service.dart';
import 'utils/route_observer.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FcmService.instance.initialize();
  runApp(MyApp(initialPostId: ShareService.postIdFromInitialLink()));
}

class MyApp extends StatelessWidget {
  final String? initialPostId;

  const MyApp({super.key, this.initialPostId});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journa',
      debugShowCheckedModeBanner: false,
      home: AuthGate(initialPostId: initialPostId),
      onGenerateRoute: (settings) {
        final postId = ShareService.postIdFromRoute(settings.name ?? '');
        if (postId != null) {
          return MaterialPageRoute(
            builder: (_) => AuthGate(initialPostId: postId),
            settings: settings,
          );
        }

        return null;
      },
      navigatorObservers: [routeObserver],
    );
  }
}
