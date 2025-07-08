import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/solar_data_provider.dart';
import 'providers/device_provider.dart';
import 'providers/automation_provider.dart';
import 'providers/plant_provider.dart';
import 'services/onboarding_service.dart';
import 'themes/app_theme.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FusionSolarAUApp());
}

class FusionSolarAUApp extends StatelessWidget {
  const FusionSolarAUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SolarDataProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => AutomationProvider()),
        ChangeNotifierProvider(create: (_) => PlantProvider()),
      ],
      child: MaterialApp(
        title: 'FusionSolarAU',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const AppEntryPoint(),
      ),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  final OnboardingService _onboardingService = OnboardingService();
  bool _isLoading = true;
  bool _shouldShowOnboarding = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Verificar primero el estado de autenticación
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Si hay un usuario autenticado, verificar si la sesión sigue siendo válida
      if (authProvider.isAuthenticated) {
        final isSessionValid = await authProvider.isUserSessionValid();
        if (!isSessionValid) {
          // Si la sesión no es válida, forzar cierre de sesión
          await authProvider.signOut();
          // No mostrar onboarding si el usuario no está autenticado
          if (mounted) {
            setState(() {
              _isLoading = false;
              _shouldShowOnboarding = false;
            });
          }
          return;
        }
      }
      
      // Verificar estado de onboarding solo si el usuario está autenticado
      if (authProvider.isAuthenticated) {
        await _checkOnboardingStatus();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _shouldShowOnboarding = false;
          });
        }
      }
      
      // Escuchar cambios de autenticación
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (!mounted) return;
        
        // Actualizar el estado de autenticación
        final isAuthenticated = event.event == AuthChangeEvent.signedIn;
        
        if (isAuthenticated) {
          _checkOnboardingStatus();
        } else {
          setState(() {
            _shouldShowOnboarding = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shouldShowOnboarding = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Esperamos a que se complete el estado de autenticación
      await Future.delayed(Duration.zero);

      // Solo verificamos el estado de onboarding si el usuario está autenticado
      if (authProvider.isAuthenticated) {
        final hasSeenOnboarding = await _onboardingService.hasSeenOnboarding();
        if (mounted) {
          setState(() {
            _shouldShowOnboarding = !hasSeenOnboarding;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _shouldShowOnboarding = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _shouldShowOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.currentUser == null) {
          return const LoginScreen();
        } else if (_shouldShowOnboarding) {
          return OnboardingScreen(onComplete: _onOnboardingComplete);
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
