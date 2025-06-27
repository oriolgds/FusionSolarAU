import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/solar_data_provider.dart';
import 'providers/device_provider.dart';
import 'providers/automation_provider.dart';
import 'themes/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  // Asegurar que el binding de Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase con las opciones predeterminadas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.currentUser != null) {
              return const HomeScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}
