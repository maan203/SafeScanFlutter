import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/assets_provider.dart';
import 'providers/contacts_provider.dart';
import 'providers/alerts_provider.dart';
import 'providers/chats_provider.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_detail_screen.dart';
import 'screens/found_item_screen.dart';
import 'screens/add_asset_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/live_location_screen.dart';
import 'screens/my_qrs_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SettingsService.instance.init();
  await NotificationService.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const SafeScanApp());
}

class SafeScanApp extends StatelessWidget {
  const SafeScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AssetsProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
        ChangeNotifierProvider(create: (_) => ChatsProvider()),
      ],
      child: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isAuth = auth.status == AuthStatus.authenticated;
        final isUnknown = auth.status == AuthStatus.unknown;

        final onSplash = state.matchedLocation == '/splash';
        final onboarding = state.matchedLocation == '/onboarding';
        final onAuth = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';
        final isPublicScan = state.matchedLocation.startsWith('/found/');

        if (isPublicScan) return null;

        // Splash screen manages its own navigation once auth resolves —
        // this is what stops onboarding from flashing before the dashboard.
        if (onSplash) return null;

        if (isUnknown) return null;

        if (isAuth) {
          if (onboarding || onAuth) return '/dashboard';
          return null;
        }

        if (!isAuth && !onAuth && !onboarding) return '/login';
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(
          path: '/found/:id',
          builder: (_, state) => FoundItemScreen(assetId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) => ChatScreen(chatId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
        GoRoute(path: '/sos', builder: (_, __) => const SosScreen()),
        GoRoute(
          path: '/report-incident',
          builder: (_, state) => ReportIncidentScreen(assetId: state.uri.queryParameters['assetId']),
        ),
        GoRoute(path: '/live-location', builder: (_, __) => const LiveLocationScreen()),
        GoRoute(path: '/emergency-contacts', builder: (_, __) => const EmergencyContactsScreen()),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        GoRoute(path: '/my-qrs', builder: (_, __) => const MyQrsScreen()),
        ShellRoute(
          builder: (context, state, child) => HomeScreen(child: child),
          routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ],
        ),
        GoRoute(
          path: '/qr-detail/:id',
          builder: (_, state) => QrDetailScreen(assetId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/add-asset', builder: (_, __) => const AddAssetScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.authenticated && auth.user != null) {
          final uid = auth.user!.uid;
          final assets = Provider.of<AssetsProvider>(context, listen: false);
          final contacts = Provider.of<ContactsProvider>(context, listen: false);
          final alerts = Provider.of<AlertsProvider>(context, listen: false);
          final chats = Provider.of<ChatsProvider>(context, listen: false);
          assets.watchAssets(uid);
          contacts.watchContacts(uid);
          alerts.watchAlerts(uid);
          chats.watchChats(uid);
        }
        return MaterialApp.router(
          title: 'SafeScan',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          routerConfig: _router,
        );
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF22C55E),
        primary: const Color(0xFF22C55E),
        onPrimary: Colors.white,
        secondary: const Color(0xFF1E293B),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      textTheme: GoogleFonts.interTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 15),
      ),
    );
  }
}
