import 'package:flutter_test/flutter_test.dart';
import 'package:securemed_iot/models/user_profile.dart';
import 'package:securemed_iot/services/mock_auth_service.dart';
import 'package:securemed_iot/providers/auth_provider.dart';

void main() {
  group('SecureMed IoT - Authentication & Firestore RBAC Tests', () {
    late MockAuthService mockAuth;
    late AuthProvider authProvider;

    setUp(() {
      mockAuth = MockAuthService(seedSampleUsers: false);
      authProvider = AuthProvider(authService: mockAuth);
    });

    tearDown(() {
      authProvider.dispose();
      mockAuth.dispose();
    });

    test('Initial state is unauthenticated when no session exists', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.userProfile, isNull);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('Registration creates user profile and logs in', () async {
      final success = await authProvider.register(
        email: 'newdoctor@hospital.local',
        password: 'Password123!',
        displayName: 'Dr. Gregory House',
        role: UserRole.doctor,
      );

      expect(success, isTrue);
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.userProfile?.email, 'newdoctor@hospital.local');
      expect(authProvider.userProfile?.displayName, 'Dr. Gregory House');
      expect(authProvider.userProfile?.role, UserRole.doctor);
      expect(authProvider.userProfile?.isDoctor, isTrue);
      expect(authProvider.userProfile?.isAdmin, isFalse);
    });

    test('SECURITY RULE: Self-assigning admin role is strictly blocked and forced to doctor', () async {
      final success = await authProvider.register(
        email: 'malicious@hospital.local',
        password: 'Password123!',
        displayName: 'Attacker Impersonator',
        role: UserRole.admin, // Attempt privilege escalation
      );

      expect(success, isTrue);
      // Verify role was downgraded to unprivileged role
      expect(authProvider.userProfile?.role, UserRole.doctor);
      expect(authProvider.userProfile?.isAdmin, isFalse);
    });

    test('Logout clears session, returns to unauthenticated, and clears profile', () async {
      await authProvider.register(
        email: 'tempdoc@hospital.local',
        password: 'Password123!',
        displayName: 'Temp Doctor',
        role: UserRole.doctor,
      );
      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.signOut();
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.userProfile, isNull);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('Login with registered credentials succeeds', () async {
      // 1. Register user
      await mockAuth.register(
        email: 'clinician@hospital.local',
        password: 'SecurePassword123!',
        displayName: 'Dr. Allison Cameron',
        role: UserRole.doctor,
      );
      await mockAuth.signOut();

      // 2. Log in via AuthProvider
      final success = await authProvider.signIn(
        email: 'clinician@hospital.local',
        password: 'SecurePassword123!',
      );

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.userProfile?.displayName, 'Dr. Allison Cameron');
    });

    test('Login with invalid password sets error state', () async {
      await mockAuth.register(
        email: 'nurse@hospital.local',
        password: 'CorrectPassword123!',
        displayName: 'Registered Nurse',
        role: UserRole.doctor,
      );
      await mockAuth.signOut();

      final success = await authProvider.signIn(
        email: 'nurse@hospital.local',
        password: 'WrongPassword!',
      );

      expect(success, isFalse);
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.errorMessage, contains('Incorrect password'));
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('UserProfile model serialization and role parsing', () {
      final profile = UserProfile(
        uid: 'TEST-UID-123',
        email: 'analyst@hospital.local',
        displayName: 'SecOps Lead',
        role: UserRole.securityAnalyst,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      expect(profile.isSecurityAnalyst, isTrue);
      expect(profile.isAdmin, isFalse);
      expect(profile.isDoctor, isFalse);

      final map = profile.toMap();
      expect(map['role'], 'security_analyst');
      expect(map['email'], 'analyst@hospital.local');

      final reconstructed = UserProfile.fromMap(map, docId: 'TEST-UID-123');
      expect(reconstructed.uid, 'TEST-UID-123');
      expect(reconstructed.role, UserRole.securityAnalyst);
    });
  });
}
