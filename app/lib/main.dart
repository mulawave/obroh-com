import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_router.dart';
import 'theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmService.I.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ObrohColors.obsidian900,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ObrohApp());
}

class ObrohApp extends StatefulWidget {
  const ObrohApp({super.key});

  @override
  State<ObrohApp> createState() => _ObrohAppState();
}

class _ObrohAppState extends State<ObrohApp> {
  @override
  void initState() {
    super.initState();
    NotificationRouter.I.bind(appNavigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..init(),
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Obroh Chronicles',
            debugShowCheckedModeBanner: false,
            theme: ObrohTheme.darkTheme,
            navigatorKey: appNavigatorKey,
            home: auth.loading
                ? const _SplashScreen()
                : auth.isAuthenticated
                ? const MainShell()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/logo.jpg',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'OBROH',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: ObrohColors.gold400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chronicles',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 4,
                color: ObrohColors.foreground.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(ObrohColors.gold400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
