// Test básico para FusionSolarAU
//
// Para realizar pruebas de interacción con widgets, usa WidgetTester
// de flutter_test. Por ejemplo, puedes enviar gestos de tap y scroll.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fusionsolarau/main.dart';

void main() {
  testWidgets('FusionSolarAU app smoke test', (WidgetTester tester) async {
    // Inicializar Hive para los tests
    await Hive.initFlutter();
    
    // Construir nuestra app y ejecutar un frame
    await tester.pumpWidget(const FusionSolarAUApp());

    // Verificar que el login screen se muestra inicialmente
    expect(find.text('FusionSolarAU'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    
    // Verificar que existe el botón de login
    expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
  });
}
