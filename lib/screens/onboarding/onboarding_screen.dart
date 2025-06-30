import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../models/onboarding_page.dart';
import '../../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({Key? key, required this.onComplete})
    : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    const OnboardingPage(
      title: 'Monitoreo Inteligente de Energía Solar',
      description:
          'Conectamos con tu sistema FusionSolar para mostrarte en tiempo real la producción, consumo y excedente de energía solar de tu hogar.',
      imagePath: 'assets/images/onboard/1.png',
      imagePrompt:
          'Imagen colorida y moderna de un panel solar con rayos de sol brillantes. En la esquina, una mascota amigable en forma de sol con ojos grandes y sonrisa cálida muestra en una tablet gráficos de producción solar en tiempo real. La pantalla muestra curvas de generación de energía, estadísticas y números positivos en verde. El fondo incluye una casa moderna con paneles solares en el techo y un cielo azul con pocas nubes.',
    ),
    const OnboardingPage(
      title: 'Automatización Basada en Excedentes',
      description:
          'Crea reglas automáticas para aprovechar al máximo tu energía solar. Activa electrodomésticos cuando hay excedente y optimiza tu consumo energético.',
      imagePath: 'assets/images/onboard/2.png',
      imagePrompt:
          'Ilustración dinámica que muestra el flujo de energía en una casa inteligente. La mascota sol ahora lleva una capa de superhéroe y está configurando reglas de automatización en un panel de control. Se muestran iconos de electrodomésticos conectados con flechas de energía verde fluyendo desde el panel solar. Visualiza una lavadora encendiéndose automáticamente con una etiqueta "Excedente detectado: 2.5kW". Incluye gráficos de barras comparando consumo normal vs optimizado, y la casa brilla con un aura verde indicando uso eficiente de energía. El estilo debe ser amigable pero técnico.',
    ),
    const OnboardingPage(
      title: 'Control Total de tu Hogar Inteligente',
      description:
          'Integra tus dispositivos Google Home para monitorear y controlar todo tu ecosistema desde una sola aplicación.',
      imagePath: 'assets/images/onboard/3.png',
      imagePrompt:
          'Ilustración interactiva de un hogar inteligente visto desde arriba o en corte transversal. La mascota sol aparece en diferentes habitaciones controlando distintos dispositivos. Muestra una sala de estar con luces inteligentes, cocina con electrodomésticos conectados, y habitación con termostato y persianas automáticas. Dispositivos Google Home distribuidos por la casa con pequeños iconos de conexión. Pantallas flotantes muestran estadísticas de ahorro energético para cada dispositivo. Incluye teléfono móvil en primer plano con la interfaz de la app FusionSolarAU mostrando el control centralizado. Paleta de colores vibrante pero armoniosa con tonos verdes y azules predominantes.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    // Guardar en Firestore que el usuario ha visto el onboarding
    print('Intentando guardar onboarding como visto...');
    await _onboardingService.markOnboardingAsSeen();
    print('Onboarding marcado como visto, continuando...');
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                ],
              ),
            ),
          ),

          // Carrusel de páginas
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _OnboardingPageView(page: page);
            },
          ),

          // Indicador de página y botones
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Indicador de página
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    activeDotColor: Theme.of(context).colorScheme.secondary,
                    dotColor: Colors.white.withOpacity(0.5),
                  ),
                ),

                const SizedBox(height: 30),

                // Botón de siguiente o finalizar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Siguiente'
                            : 'Comenzar',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botón para saltar
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'Saltar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

class _OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;

  const _OnboardingPageView({Key? key, required this.page}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 80), // Más margen abajo
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Imagen ilustrativa
          SizedBox(
            height: 220,
            child:
                Container(
                      margin: const EdgeInsets.only(bottom: 40),
                      child: Image.asset(
                        page.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback si la imagen no existe
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 80,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOutQuad,
                      duration: 600.ms,
                    ),
          ),

          // Título
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

          const SizedBox(height: 20),

          // Descripción scrollable y centrada
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  page.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
