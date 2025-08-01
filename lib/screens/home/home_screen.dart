import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const ProfileScreen(),
    ];
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar si la sesión sigue siendo válida
    if (authProvider.isAuthenticated) {
      final isSessionValid = await authProvider.isUserSessionValid();
      if (!isSessionValid && mounted) {
        await authProvider.signOut();
        if (mounted) {
          _navigateToLogin();
        }
        return;
      }
      // Actualizar último inicio de sesión solo si la sesión es válida
      if (mounted) {
        await _updateLastLogin();
      }
    } else if (mounted) {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    
    // Usar un post-frame callback para asegurarnos de que el widget esté montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  Future<void> _updateLastLogin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('users').upsert({
          'id': user.id,
          'last_login': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error updating last login: $e');
      // Si hay un error al actualizar el último login, forzamos cierre de sesión
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.signOut();
        _navigateToLogin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de autenticación
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Usar un efecto para manejar la navegación cuando el estado de autenticación cambia
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!authProvider.isAuthenticated) {
        _navigateToLogin();
      }
    });
    
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
