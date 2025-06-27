import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo y título
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  
                  // Tarjeta de login
                  _buildLoginCard(context),
                  
                  const SizedBox(height: 24),
                  
                  // Información adicional
                  _buildInfoSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.solar_power,
            size: 60,
            color: Color(0xFF4CAF50),
          ),
        ).animate().scale(duration: 600.ms).fadeIn(),
        
        const SizedBox(height: 24),
        
        Text(
          'FusionSolarAU',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ).animate().slideY(begin: 0.3, duration: 600.ms).fadeIn(),
        
        const SizedBox(height: 8),
        
        Text(
          'Automatización Inteligente con Energía Solar',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ).animate().slideY(begin: 0.3, duration: 600.ms, delay: 200.ms).fadeIn(),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Text(
              'Iniciar Sesión',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Conecta con tu cuenta de Google para comenzar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: authProvider.isLoading ? null : () async {
                      final userCredential = await authProvider.signInWithGoogle();
                      if (userCredential == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(authProvider.errorMessage ?? 'Error al iniciar sesión'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Image.asset(
                            'assets/images/google_logo.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.login, size: 20);
                            },
                          ),
                    label: Text(
                      authProvider.isLoading ? 'Iniciando sesión...' : 'Continuar con Google',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.3, duration: 600.ms, delay: 400.ms).fadeIn();
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '¿Qué puedes hacer?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildFeatureItem(
            context,
            Icons.flash_on,
            'Monitoreo en tiempo real',
            'Visualiza tu producción y consumo solar',
          ),
          
          _buildFeatureItem(
            context,
            Icons.home_filled,
            'Control inteligente',
            'Automatiza dispositivos Google Home',
          ),
          
          _buildFeatureItem(
            context,
            Icons.savings,
            'Optimización energética',
            'Aprovecha al máximo tu energía solar',
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 600.ms, delay: 600.ms).fadeIn();
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
