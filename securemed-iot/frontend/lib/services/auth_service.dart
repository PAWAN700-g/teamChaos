import '../models/user_profile.dart';

abstract class AuthService {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;

  Future<UserProfile> signIn({
    required String email,
    required String password,
  });

  Future<UserProfile> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  });

  Future<void> signOut();

  Future<UserProfile?> fetchUserProfile(String uid);
}
