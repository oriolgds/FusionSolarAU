import 'package:flutter/material.dart';
import '../profile/fusion_solar_config_screen.dart';

class FusionSolarNotConfiguredScreen extends StatelessWidget {
  final VoidCallback? onConfigured;
  
  const FusionSolarNotConfiguredScreen({
    super.key, 
    this.onConfigured,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Control'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.solar_power_outlined,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Fusion Solar no configurado',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Para ver los datos de tu instalación solar, necesitas configurar tu cuenta de Fusion Solar.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Configurar ahora'),
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FusionSolarConfigScreen(
                        onConfigUpdated: () {
                          // Esto se llama mientras aún estamos en la pantalla de configuración
                          // Útil para actualizaciones en tiempo real
                        },
                      ),
                    ),
                  );
                  
                  // Si la configuración fue exitosa, notificar al padre
                  if (result == true && onConfigured != null) {
                    // Informamos al usuario que estamos actualizando
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Obteniendo datos solares...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    
                    // Notificar al dashboard para refrescar datos
                    onConfigured!();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
