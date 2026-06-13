import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/shared/firebase_service.dart';
import 'features/auth/setup_screen.dart';
import 'features/dashboard/live_dashboard.dart';
import 'features/session/session_router.dart';
import 'features/qudwah/qudwah_form.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAI Sektor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F172A),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RootNavigationRouter(),
    );
  }
}

class RootNavigationRouter extends ConsumerStatefulWidget {
  const RootNavigationRouter({super.key});

  @override
  ConsumerState<RootNavigationRouter> createState() => _RootNavigationRouterState();
}

class _RootNavigationRouterState extends ConsumerState<RootNavigationRouter> {
  String _currentRoute = '/';
  String? _walikelasParam;

  @override
  void initState() {
    super.initState();
    _parseUrl();
  }

  void _parseUrl() {
    final uri = Uri.base;
    final path = uri.fragment; // E.g. /session or /qudwah?walikelas=Ahsan

    if (path.contains('/session')) {
      setState(() {
        _currentRoute = '/session';
      });
    } else if (path.contains('/qudwah')) {
      setState(() {
        _currentRoute = '/qudwah';
        // Parse parameters if any
        final subUri = Uri.parse(path);
        _walikelasParam = subUri.queryParameters['walikelas'];
      });
    } else {
      setState(() {
        _currentRoute = '/';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configStreamProvider);
    final isAuthenticated = ref.watch(sessionAuthStateProvider);

    return configAsync.when(
      data: (config) {
        if (config == null) {
          // If no configuration found, force Setup/Registration Screen
          return SetupScreen(
            onSetupComplete: () {
              setState(() {
                _currentRoute = '/';
              });
            },
          );
        }

        // Routing based on parsed hash route
        switch (_currentRoute) {
          case '/session':
            return const SessionRouter();
          case '/qudwah':
            return QudwahForm(initialWalikelas: _walikelasParam);
          case '/':
          default:
            if (!isAuthenticated) {
              return SetupScreen(
                onSetupComplete: () {
                  setState(() {
                    _currentRoute = '/';
                  });
                },
              );
            }
            return const LiveDashboard();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      ),
      error: (e, stack) => Scaffold(
        body: Center(
          child: Text(
            'Gagal menginisialisasi aplikasi: $e',
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
