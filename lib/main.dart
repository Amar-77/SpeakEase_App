// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// // Imports
// import 'screens/auth/login_screen.dart';
// import 'screens/student/home/student_home.dart';
// import 'screens/teacher/home/teacher_home.dart';


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const MaterialApp(
//     debugShowCheckedModeBanner: false,
//     home: AuthWrapper(),
//   ));
// }

// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         // 1. Not Logged In -> Show Login
//         if (!snapshot.hasData) {
//           return const LoginScreen();
//         }

//         // 2. Logged In -> Check Role
//         User user = snapshot.data!;
//         return FutureBuilder<DocumentSnapshot>(
//           future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Scaffold(body: Center(child: CircularProgressIndicator()));
//             }

//             if (snapshot.hasData && snapshot.data!.exists) {
//               String role = snapshot.data!['role'];
//               if (role == 'teacher') {
//                 return const TeacherHome();
//               } else {
//                 return const StudentHome();
//               }
//             }

//             return const LoginScreen(); // Fallback
//           },
//         );
//       },
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speakease/screens/auth/auth_gate.dart';
import 'package:speakease/screens/auth/login_screen.dart';
import 'package:speakease/screens/student/home/student_home.dart';
import 'package:speakease/screens/teacher/home/teacher_home.dart';

// --- 1. Top-Level Background Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// --- 2. Global Channel & Plugin Setup ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.',
  importance: Importance.max, // Forces the pop-up (Heads-up)
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  // --- 3. Notification Configuration ---
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Local Notifications (Needed for Foreground Pop-ups)
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher'); // Ensure icon exists!

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create the High Importance Channel on the device
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Set iOS/Android Foreground presentation options
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // 4. Request Permission (Crucial)
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 5. Foreground Listener: Manually trigger local notification
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
            playSound: true,
          ),
        ),
      );
    }
  });

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthGate(),
  ));
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Stream 1: Listens for Login/Logout
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Not logged in? Show Login Screen.
        if (!authSnapshot.hasData) return const LoginScreen();

        User user = authSnapshot.data!;

        // Stream 2: Listens to their Firestore Document (Replaces FutureBuilder)
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {

            // While fetching data, show loading
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
            }

            // Once the document exists and has data, route them!
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              var data = userSnapshot.data!.data() as Map<String, dynamic>;
              String role = data['role'] ?? 'student'; // Fallback to student just in case

              return role == 'teacher' ? const TeacherHome() : const StudentHome();
            }

            // THE MAGIC FIX: If Auth is true, but Firestore doc doesn't exist YET
            // (meaning the race condition is happening during signup),
            // just keep showing the loading spinner. Do NOT return the LoginScreen here!
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)));
          },
        );
      },
    );
  }
}