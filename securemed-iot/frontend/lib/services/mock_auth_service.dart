import 'dart:async';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// In-Memory Mock Authentication Service for testing and offline development.
class MockAuthService implements AuthService {
  final Map<String, UserProfile> _mockDatabase = {};
  final Map<String, String> _passwords = {};

  final StreamController<UserProfile?> _authController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;

  MockAuthService({bool seedSampleUsers = true}) {
    if (seedSampleUsers) {
      _seedUsers();
    }
  }

  void _seedUsers() {
    final now = DateTime.now();
    final doctor = UserProfile(
      uid: 'MOCK-DOC-001',
      email: 'doctor@hospital.local',
      displayName: 'Dr. Sarah Connor, MD',
      role: UserRole.doctor,
      createdAt: now,
      updatedAt: now,
    );
    final analyst = UserProfile(
      uid: 'MOCK-SEC-002',
      email: 'analyst@hospital.local',
      displayName: 'Alex Vance, CISSP',
      role: UserRole.securityAnalyst,
      createdAt: now,
      updatedAt: now,
    );
    final admin = UserProfile(
      uid: 'MOCK-ADM-003',
      email: 'admin@hospital.local',
      displayName: 'Hospital Chief InfoSec Officer',
      role: UserRole.admin,
      createdAt: now,
      updatedAt: now,
    );

    _mockDatabase[doctor.uid] = doctor;
    _passwords[doctor.email] = 'Password123!';

    _mockDatabase[analyst.uid] = analyst;
    _passwords[analyst.email] = 'Password123!';

    _mockDatabase[admin.uid] = admin;
    _passwords[admin.email] = 'Password123!';
  }

  @override
  Stream<UserProfile?> get authStateChanges async* {
    yield _currentUser;
    yield* _authController.stream;
  }

  @override
  UserProfile? get currentUser => _currentUser;

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async {
    return _mockDatabase[uid];
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // SECURITY: Users cannot self-assign the admin role
    final enforcedRole = (role == UserRole.admin) ? UserRole.doctor : role;

    final existing = _mockDatabase.values.where((u) => u.email.toLowerCase() == email.toLowerCase());
    if (existing.isNotEmpty) {
      throw Exception('An account with this email already exists.');
    }

    final now = DateTime.now();
    final uid = 'MOCK-UID-${DateTime.now().millisecondsSinceEpoch}';
    final profile = UserProfile(
      uid: uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: enforcedRole,
      createdAt: now,
      updatedAt: now,
    );

    _mockDatabase[uid] = profile;
    _passwords[email.trim()] = password;
    _currentUser = profile;
    _authController.add(profile);

    return profile;
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    UserProfile? matchedUser;
    for (final user in _mockDatabase.values) {
      if (user.email.toLowerCase() == normalizedEmail) {
        matchedUser = user;
        break;
      }
    }

    if (matchedUser == null) {
      throw Exception('Invalid credentials: User not found.');
    }

    final storedPw = _passwords[matchedUser.email];
    if (storedPw != password) {
      throw Exception('Invalid credentials: Incorrect password.');
    }

    _currentUser = matchedUser;
    _authController.add(matchedUser);
    return matchedUser;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _currentUser = null;
    _authController.add(null);
  }

  void dispose() {
    _authController.close();
  }
}
