import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';

import 'create_account_zamil.dart';
import 'welcome.dart';
import 'Login.dart';
import 'forgot_password.dart';
import 'create_account_captain.dart';
import 'HomeZamil.dart';
import 'ProfileZamil.dart';
import 'BookingTripZamil.dart';
import 'ChattingZamil.dart';
import 'ChatRoomZamil.dart';
import 'TripDetailsZamil.dart';
import 'HomeCaptain.dart';
import 'ProfileCaptain.dart';
import 'AvailableTripCaptain.dart';
import 'MakingTripCaptain.dart';
import 'GroupCaptain.dart';
import 'ChatRoomCaptain.dart';
import 'Passengers.dart';
import 'forgot_password_email.dart';
import 'otp_verification_page.dart';
import 'Reports.dart';
import 'Notifications.dart';
import 'RecurrentTrips.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  void handleNotificationClick(RemoteMessage message) {
    if (message.data['route'] == '/CreateAccCaptain') {
      final reason = message.data['reason'] ?? "Error in documents";
      _rootNavigatorKey.currentContext?.go('/CreateAccCaptain', extra: reason);
    } else if (message.data['route'] == '/CreateAccZamil') {
      final reason = message.data['reason'] ?? "Error in documents";
      _rootNavigatorKey.currentContext?.go('/CreateAccZamil', extra: reason);
    }
  }

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      Future.delayed(const Duration(seconds: 1), () {
        handleNotificationClick(message);
      });
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    handleNotificationClick(message);
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Welcome()),

      GoRoute(
        path: '/CreateAccZamil',
        builder: (context, state) {
          final rejectReason = state.extra as String?;
          return CreateAccountPage(rejectReason: rejectReason);
        },
      ),

      GoRoute(path: '/login', builder: (context, state) => const Login()),
      GoRoute(
        path: '/forgot-password-email',
        builder: (context, state) => const ForgotPasswordEmailPage(),
      ),

      GoRoute(
        path: '/CreateAccCaptain',
        builder: (context, state) {
          final rejectReason = state.extra as String?;
          return CreateAccCaptain(rejectReason: rejectReason);
        },
      ),

      GoRoute(path: '/home', builder: (context, state) => const HomeZamil()),
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          final zamilEmail = state.extra as String?;

          return ProfileZamil(specificZamilEmail: zamilEmail);
        },
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) => BookingTripZamil(),
      ),
      GoRoute(
        path: '/chatList',
        builder: (context, state) => const ChattingZamil(),
      ),
      GoRoute(
        path: '/chatRoom',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};

          return ChatRoomZamil(
            groupId: extra['groupId'] ?? 0,
            groupName: extra['groupName'] ?? 'Unknown Group',
            tripType: extra['tripType'],
          );
        },
      ),
      GoRoute(
        path: '/TripDetailsZamil',
        builder: (context, state) {
          final tripData = state.extra as Map<String, dynamic>;
          return TripDetailsZamil(trip: tripData);
        },
      ),
      GoRoute(
        path: '/homeCaptain',
        builder: (context, state) => const HomeCaptain(),
      ),
      GoRoute(
        path: '/groupCaptain',
        builder: (context, state) => const GroupCaptain(),
      ),
      GoRoute(
        path: '/profileCaptain',
        builder: (context, state) {
          final passedEmail = state.extra as String?;
          return ProfileCaptain(specificCaptainEmail: passedEmail);
        },
      ),
      GoRoute(
        path: '/chatCaptainRoom',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final groupId = extra?['groupId'] ?? 0;
          final groupName = extra?['groupName'] ?? 'Unknown Group';

          return ChatRoomCaptain(groupId: groupId, groupName: groupName);
        },
      ),
      GoRoute(
        path: '/passengers',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final groupId = extra['groupId'] ?? 0;

          return Passengers(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/availableTripCaptain',
        builder: (context, state) => const AvailableTripCaptain(),
      ),
      GoRoute(
        path: '/createTripCaptain',
        builder: (context, state) => const MakingTripCaptain(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final email = state.extra as String;
          return OtpVerificationPage(email: email);
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final email = state.extra as String;
          return ForgotPasswordPage(email: email);
        },
      ),
      GoRoute(
        path: '/reports/:role',
        builder: (context, state) {
          final role = state.pathParameters['role'] ?? 'unknown';

          final extraData = state.extra as Map<String, dynamic>? ?? {};

          return Reports(
            userRole: role,
            userName: extraData['name'] ?? 'Unknown User',
            userEmail: extraData['email'] ?? 'No Email',
            userPhone: extraData['phone'] ?? 'No Phone',
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const Notifications(),
      ),
      GoRoute(
        path: '/recurrentTrips',
        builder: (context, state) {
          final String? emailFromState = state.extra as String?;
          final String captainEmail = emailFromState ?? "majd@gmail.com";
          return RecurrentTrips(captainEmail: captainEmail);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Sawa App',
      theme: ThemeData(
        primaryColor: const Color(0xFF1D9E75),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9E75)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
