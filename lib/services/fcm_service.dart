import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (mostly for iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get the token for testing/server
      String? token = await _firebaseMessaging.getToken();
      print("FCM Token: \$token");

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: \${message.data}');

        if (message.notification != null) {
          print(
            'Message also contained a notification: \${message.notification}',
          );
          // Ideally show local notification here
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }
}
