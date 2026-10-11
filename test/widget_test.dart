import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toolbox/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets('ToolboxApp smoke test and navigation verify', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ToolboxApp()));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify main app renders
    expect(find.byType(ToolboxApp), findsOneWidget);

    // Verify Live Resource Telemetry section is present
    expect(find.text('LIVE RESOURCE TELEMETRY'), findsOneWidget);

    // Verify Hardware & Platform section is present
    expect(find.text('HARDWARE & PLATFORM'), findsOneWidget);
  });
}
