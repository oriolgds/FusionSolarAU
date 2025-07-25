# FusionSolarAU: Automatización Inteligente con Google Home y Fusion Solar

<div align="center">
  <img src="https://via.placeholder.com/150x150/4CAF50/FFFFFF?text=FS" alt="FusionSolarAU Logo" width="150"/>
  
  **Optimiza tu energía solar con automatización inteligente**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.8.1-blue.svg)](https://flutter.dev/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

## 🌞 Descripción General

FusionSolarAU es una aplicación innovadora que conecta tu instalación solar de Fusion Solar con los dispositivos Google Home de tu hogar, permitiendo una gestión automática e inteligente de la energía. La aplicación analiza en tiempo real los datos de producción, consumo y excedentes de tu instalación fotovoltaica para optimizar el uso de tus dispositivos inteligentes.

<div align="center">
  <a href="https://play.google.com/store/apps/details?id=com.oriolgds.fusionsolarau">
    <img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="80"/>
  </a>
  
  <a href="https://play.google.com/apps/testing/com.oriolgds.fusionsolarau">
    <img alt="Join Beta Testing" src="https://img.shields.io/badge/Join-Beta%20Testing-orange?style=for-the-badge&logo=google-play" height="50" style="margin-top: 15px;"/>
  </a>
</div>

## ✨ Características Principales

### 🔋 Automatización Basada en Excedentes
- **Activación inteligente**: Activa automáticamente electrodomésticos cuando detecta excedentes de energía solar
- **Carga de vehículos eléctricos**: Programa cargas para aprovechar al máximo la energía solar disponible
- **Priorización de dispositivos**: Sistema de prioridades para optimizar el uso de energía

### ⚡ Optimización Energética
- **Control de temperatura**: Ajusta termostatos inteligentes según la producción solar prevista
- **Gestión de iluminación**: Controla luces exteriores en función de la energía disponible
- **Gestión de electrodomésticos**: Optimiza el funcionamiento de lavadoras, lavavajillas, etc.

### 📊 Monitorización en Tiempo Real
- **Panel de control intuitivo**: Visualiza producción, consumo y estado de dispositivos
- **Alertas personalizables**: Notificaciones para cambios significativos en producción o consumo
- **Estadísticas detalladas**: Históricos de producción, consumo y ahorro energético

### 🏠 Integración Total
- **Ecosistema Google Home**: Compatibilidad total con dispositivos Google Home
- **Escenarios personalizados**: Configuración de rutinas según tus hábitos de consumo
- **Control por voz**: Integración con asistentes de voz para control manual

## 🚀 Beneficios

- **💰 Ahorro económico**: Reduce tu factura eléctrica aprovechando al máximo la energía solar
- **🌱 Sostenibilidad**: Minimiza la dependencia de la red eléctrica convencional
- **🛋️ Comodidad**: Automatización inteligente sin necesidad de intervención manual
- **🎯 Control total**: Personalización completa de las reglas de automatización

## 📱 Capturas de Pantalla

### Panel Principal
- Monitorización en tiempo real de producción y consumo solar
- Tarjetas informativas con datos clave
- Estado de automatización y acciones rápidas

### Gestión de Dispositivos
- Lista completa de dispositivos Google Home conectados
- Control individual de cada dispositivo
- Filtrado por habitaciones y tipos de dispositivo

### Automatización Inteligente
- Reglas de automatización personalizables
- Condiciones basadas en excedentes, tiempo y nivel de batería
- Estadísticas de activación de reglas

### Perfil de Usuario
- Información de la cuenta Google
- Estadísticas de uso de la aplicación
- Configuración de preferencias

## 🛠️ Tecnologías Utilizadas

- **Framework**: Flutter 3.8.1
- **Gestión de Estado**: Provider Pattern
- **Almacenamiento Local**: Hive + SharedPreferences
- **Autenticación**: Google Sign-In
- **UI/UX**: Material Design 3
- **Animaciones**: Flutter Animate

## 🏗️ Arquitectura

```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── models/                   # Modelos de datos
│   ├── solar_data.dart      # Datos de producción solar
│   ├── smart_device.dart    # Dispositivos inteligentes
│   ├── automation_rule.dart # Reglas de automatización
│   └── user.dart           # Datos del usuario
├── providers/               # Gestión de estado
│   ├── auth_provider.dart
│   ├── solar_data_provider.dart
│   ├── device_provider.dart
│   └── automation_provider.dart
├── services/               # Servicios de datos
│   ├── fusion_solar_service.dart
│   ├── google_home_service.dart
│   ├── automation_service.dart
│   └── auth_service.dart
├── screens/               # Pantallas de la aplicación
│   ├── auth/             # Autenticación
│   ├── home/             # Pantalla principal
│   ├── dashboard/        # Panel de control
│   ├── devices/          # Gestión de dispositivos
│   ├── automation/       # Automatización
│   └── profile/          # Perfil de usuario
└── themes/               # Temas y estilos
    └── app_theme.dart
```

## 🚀 Instalación y Configuración

### Prerrequisitos
- Flutter SDK 3.8.1 o superior
- Dart SDK 3.0.0 o superior
- Cuenta de Google para autenticación

### Instalación

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/tu-usuario/FusionSolarAU.git
   cd FusionSolarAU
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar autenticación de Google**
   - Crea un proyecto en Google Cloud Console
   - Habilita Google Sign-In API
   - Configura los archivos de autenticación según la plataforma

4. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

### Ejecución en diferentes plataformas

- **Web**: `flutter run -d chrome`
- **Android**: `flutter run -d android`
- **iOS**: `flutter run -d ios`
- **Windows**: `flutter run -d windows`

## 📋 Funcionalidades Implementadas

- ✅ Autenticación con Google
- ✅ Panel de control con datos en tiempo real
- ✅ **Integración real con API de FusionSolar**
- ✅ **Datos reales de producción, consumo e ingresos**
- ✅ **Estado de salud de las instalaciones solares**
- ✅ Gestión de dispositivos Google Home (simulados)
- ✅ Sistema de reglas de automatización
- ✅ Selector de plantas/instalaciones múltiples
- ✅ Perfil de usuario y configuración
- ✅ Temas claro y oscuro
- ✅ Interfaz responsive y moderna

## 🔮 Próximas Funcionalidades

- 🔄 Conexión real con Google Home API
- 🔄 Notificaciones push
- 🔄 Gráficos avanzados de consumo histórico
- 🔄 Predicción meteorológica
- 🔄 Exportación de datos
- 🔄 Configuración avanzada de automatización
- 🔄 Alertas basadas en estado de salud de la instalación

## 🌟 Datos Reales de FusionSolar

La aplicación ahora obtiene datos reales de tu instalación solar a través de la API oficial de FusionSolar:

### 📊 Métricas en Tiempo Real
- **Producción diaria**: Energía generada hoy en kWh
- **Producción mensual**: Energía generada este mes
- **Producción total**: Energía generada desde la instalación
- **Consumo diario**: Energía consumida hoy
- **Energía a red**: Energía exportada a la red eléctrica
- **Ingresos**: Ingresos generados por la venta de energía
- **Estado de salud**: Estado operativo de la instalación

### 🔧 Configuración Requerida
Para acceder a los datos reales, necesitas:
1. Credenciales de API de FusionSolar (proporcionadas por tu instalador)
2. Configurar la conexión en la sección "Configuración FusionSolar" del perfil
3. Seleccionar tu instalación si tienes múltiples plantas

**Importante**: Cada usuario de FusionSolar solo puede estar asociado a una cuenta de la aplicación por motivos de seguridad.

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Por favor, lee nuestras [directrices de contribución](CONTRIBUTING.md) antes de enviar un PR.

1. Fork el proyecto
2. Crea una rama para tu funcionalidad (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -m 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 📚 Documentación Oficial de Fusion Solar

- [Documentación de la API de Fusion Solar (Huawei)](https://support.huawei.com/enterprise/en/doc/EDOC1100465337)

## 📞 Soporte

Si tienes alguna pregunta o necesitas ayuda:

- 📧 Email: oriolginger2008@gmail.com
- 📖 Wiki: [Documentación completa](https://github.com/tu-usuario/FusionSolarAU/wiki)

## 🙏 Agradecimientos

- Al equipo de Flutter por el increíble framework
- A Google por las APIs de autenticación y Home
- A la comunidad de desarrolladores de energías renovables

---

<div align="center">
  <p>Hecho con ❤️ para un futuro más sostenible</p>
  <p>© 2024 FusionSolarAU. Todos los derechos reservados.</p>
</div>
