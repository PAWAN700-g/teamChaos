import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securemed_iot/main.dart';
import 'package:securemed_iot/services/mock_auth_service.dart';

void main() {
  testWidgets('SecureMedApp renders AuthScreen initially and blocks unauthenticated dashboard',
      (WidgetTester tester) async {
    final mockAuth = MockAuthService(seedSampleUsers: false);
    await tester.pumpWidget(SecureMedApp(authService: mockAuth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SecureMed IoT'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
    expect(find.text('Secure Login'), findsOneWidget);

    expect(find.text('Fleet Overview & Security State'), findsNothing);
  });

  testWidgets('DashboardScreen renders without any overflows on standard mobile (390x844)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAuth = MockAuthService(seedSampleUsers: true);
    await tester.pumpWidget(SecureMedApp(authService: mockAuth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('login_email_field')), 'doctor@hospital.local');
    await tester.enterText(find.byKey(const ValueKey('login_password_field')), 'Password123!');
    await tester.pump();

    await tester.tap(find.text('Secure Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Clinical Dashboard'), findsOneWidget);
    expect(find.text('Fleet Overview & Security State'), findsOneWidget);
    expect(find.text('Latest Telemetry Vitals'), findsOneWidget);
    expect(find.text('Heart Rate Trend'), findsOneWidget);
  });

  testWidgets('Multi-page NavigationBar transitions seamlessly across all specialized screens',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAuth = MockAuthService(seedSampleUsers: true);
    await tester.pumpWidget(SecureMedApp(authService: mockAuth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('login_email_field')), 'doctor@hospital.local');
    await tester.enterText(find.byKey(const ValueKey('login_password_field')), 'Password123!');
    await tester.pump();

    await tester.tap(find.text('Secure Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 1. Tab 0: Clinical Dashboard
    expect(find.text('Clinical Dashboard'), findsOneWidget);
    expect(find.text('Total Devices'), findsOneWidget);

    // 2. Tab 1: Devices
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    expect(find.text('Device Fleet'), findsOneWidget);
    expect(find.text('Connected Device Fleet'), findsOneWidget);

    // 3. Tab 2: Security Center
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Security Operations Center (SIEM)'), findsOneWidget);
    expect(find.text('Attack Detection History'), findsOneWidget);

    // 4. Tab 3: Attack Simulation
    await tester.tap(find.text('Simulation'));
    await tester.pumpAndSettle();
    expect(find.text('Cybersecurity Attack Simulator'), findsOneWidget);
    expect(find.text('1. Device Impersonation'), findsOneWidget);

    // 5. Tab 4: Audit Logs
    await tester.tap(find.text('Audit Logs'));
    await tester.pumpAndSettle();
    expect(find.text('Audit Ledger Chain'), findsWidgets);
    expect(find.text('Hash-Chain Integrity Status'), findsOneWidget);

    // 6. Tab 5: Profile & Settings
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('User Profile & System Administration'), findsOneWidget);
    expect(find.text('RBAC Security Permissions Matrix'), findsOneWidget);
  });
}
