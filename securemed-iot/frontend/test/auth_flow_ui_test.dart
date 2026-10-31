import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securemed_iot/main.dart';
import 'package:securemed_iot/services/mock_auth_service.dart';

void main() {
  testWidgets('Complete End-to-End Auth UI Flow: Register -> Dashboard -> Logout -> Login',
      (WidgetTester tester) async {
    // Set screen size to prevent desktop layout constraints in test
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockAuth = MockAuthService(seedSampleUsers: false);
    await tester.pumpWidget(SecureMedApp(authService: mockAuth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Initial State: Unauthenticated, AuthScreen visible
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
    expect(find.text('Connected Medical Device Fleet'), findsNothing); // Blocked!

    // 2. Switch to Register Tab
    await tester.tap(find.text('Register Account'));
    await tester.pumpAndSettle();

    // 3. Fill in Registration Form using ValueKeys
    await tester.enterText(find.byKey(const ValueKey('register_name_field')), 'Dr. James Wilson');
    await tester.enterText(find.byKey(const ValueKey('register_email_field')), 'jwilson@hospital.local');
    await tester.enterText(find.byKey(const ValueKey('register_password_field')), 'HospitalPass2026!');
    await tester.pump();

    // 4. Tap 'Create Protected Account'
    await tester.tap(find.text('Create Protected Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 5. Verify User Lands on Secured Dashboard
    expect(find.text('Dr. James Wilson'), findsOneWidget);
    expect(find.text('CLINICIAN / DOCTOR'), findsWidgets);
    expect(find.text('Connected Medical Device Fleet'), findsOneWidget);
    expect(find.text('Post-Quantum Cryptographic Architecture'), findsOneWidget);

    // 6. Test Logout: Tap 'Log Out'
    await tester.tap(find.widgetWithText(OutlinedButton, 'Log Out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 7. Verify Unauthenticated Route Guard kicks in: Back on AuthScreen
    expect(find.text('Secure Login'), findsOneWidget);
    expect(find.text('Connected Medical Device Fleet'), findsNothing);

    // 8. Test Log In with the registered credentials
    await tester.enterText(find.byKey(const ValueKey('login_email_field')), 'jwilson@hospital.local');
    await tester.enterText(find.byKey(const ValueKey('login_password_field')), 'HospitalPass2026!');
    await tester.pump();

    await tester.tap(find.text('Secure Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 9. Verify Logged Back In
    expect(find.text('Dr. James Wilson'), findsOneWidget);
    expect(find.text('Connected Medical Device Fleet'), findsOneWidget);
  });
}
