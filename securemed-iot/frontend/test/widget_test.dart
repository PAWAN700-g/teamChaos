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

    // Verify unauthenticated user lands on AuthScreen (Login)
    expect(find.text('SecureMed IoT'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
    expect(find.text('Secure Login'), findsOneWidget);

    // Verify unauthenticated user CANNOT see the Dashboard
    expect(find.text('Connected Medical Device Fleet'), findsNothing);
    expect(find.text('Post-Quantum Cryptographic Architecture'), findsNothing);
  });
}
