import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/solar_data_provider.dart';
import 'providers/device_provider.dart';
import 'providers/automation_provider.dart';
import 'services/onboarding_service.dart';
import 'themes/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  // Asegurar que el binding de Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase con las opciones predeterminadas
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Solo esperamos a que se complete la inicialización
    await Future.delayed(Duration.zero);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkOnboardingStatus() async {
    final hasSeenOnboarding = await _onboardingService.hasSeenOnboarding();
    setState(() {
      _shouldShowOnboarding = !hasSeenOnboarding;
    });
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
        // Si no está autenticado, mostrar pantalla de login
        if (authProvider.currentUser == null) {
          // Resetear el estado de onboarding cuando no hay usuario
          if (_shouldShowOnboarding) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _shouldShowOnboarding = false;
              });
            });
          }
          return const LoginScreen();
        } 
        
        // Si está autenticado, verificar onboarding
        if (!_shouldShowOnboarding) {
          // Solo verificar onboarding una vez cuando el usuario está autenticado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkOnboardingStatus();
          });
        }
        
        // Mostrar onboarding si es necesario
        if (_shouldShowOnboarding) {
          return OnboardingScreen(onComplete: _onOnboardingComplete);
        }
        
        // Mostrar pantalla principal
        return const HomeScreen();
      },
    );
  }
}
