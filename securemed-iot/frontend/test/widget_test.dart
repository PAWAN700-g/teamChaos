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

    expect(find.text('Connected Device Fleet'), findsNothing);
    expect(find.text('Post-Quantum Cryptographic Architecture'), findsNothing);
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

    expect(find.text('SecureMed IoT'), findsOneWidget);
    expect(find.text('Connected Device Fleet'), findsOneWidget);
    expect(find.text('Post-Quantum Cryptographic Architecture'), findsOneWidget);
    expect(find.text('ICU Patient Monitor #01'), findsOneWidget);
  });

  testWidgets('Multi-page NavigationBar transitions seamlessly across all 5 specialized tabs',
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

    // 1. Verify Tab 0: Fleet
    expect(find.text('Connected Device Fleet'), findsOneWidget);

    // 2. Switch to Tab 1: PQC Crypto
    await tester.tap(find.text('PQC Crypto'));
    await tester.pumpAndSettle();
    expect(find.text('Quantum-Resistant Cryptographic Engine'), findsOneWidget);
    expect(find.text('Live PQC Cryptographic Self-Test'), findsOneWidget);

    // 3. Switch to Tab 2: Threats SIEM
    await tester.tap(find.text('Threats'));
    await tester.pumpAndSettle();
    expect(find.text('Cybersecurity Threat SIEM & Defense'), findsOneWidget);
    expect(find.text('Emergency Device Revocation'), findsOneWidget);

    // 4. Switch to Tab 3: Audit Log Chain
    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();
    expect(find.text('Tamper-Evident SHA-256 Audit Ledger'), findsOneWidget);
    expect(find.text('Current Audit Head Digest'), findsOneWidget);

    // 5. Switch to Tab 4: Profile & Settings
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('User Profile & System Administration'), findsOneWidget);
    expect(find.text('RBAC Security Permissions Matrix'), findsOneWidget);
  });
}
