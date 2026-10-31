import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  UserProfile? _cachedProfile;

  FirebaseAuthService({
    fb_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  UserProfile? get currentUser => _cachedProfile;

  @override
  Stream<UserProfile?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) {
        _cachedProfile = null;
        return null;
      }
      try {
        final profile = await fetchUserProfile(fbUser.uid);
        _cachedProfile = profile;
        return profile;
      } catch (e) {
        // Fallback default profile if firestore read fails temporarily
        final fallback = UserProfile(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? 'Medical User',
          role: UserRole.doctor, // Default unprivileged role
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _cachedProfile = fallback;
        return fallback;
      }
    });
  }

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async {
    final docSnapshot = await _firestore.collection('users').doc(uid).get();
    if (docSnapshot.exists) {
      return UserProfile.fromFirestore(docSnapshot);
    }
    return null;
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    // SECURITY ENFORCEMENT:
    // Never allow users to self-assign the admin role.
    // Default new self-registered accounts to unprivileged doctor or security_analyst.
    final sanitizedRole = (role == UserRole.admin) ? UserRole.doctor : role;

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final fbUser = userCredential.user;
    if (fbUser == null) {
      throw Exception('User registration failed: No user returned by Firebase Auth.');
    }

    // Update Firebase Auth display name
    await fbUser.updateDisplayName(displayName.trim());

    final now = DateTime.now();
    final profile = UserProfile(
      uid: fbUser.uid,
      email: fbUser.email ?? email.trim(),
      displayName: displayName.trim(),
      role: sanitizedRole,
      createdAt: now,
      updatedAt: now,
    );

    // Save profile document in Firestore collection 'users'
    await _firestore.collection('users').doc(fbUser.uid).set(profile.toMap());

    // Record audit event for user creation
    try {
      await _firestore.collection('audit_events').add({
        'eventId': 'EVT-${now.millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': 'USER_REGISTRATION',
        'actorUid': fbUser.uid,
        'actorRole': sanitizedRole.id,
        'details': {
          'email': fbUser.email,
          'assignedRole': sanitizedRole.id,
        },
      });
    } catch (_) {
      // Non-blocking audit log catch
    }

    _cachedProfile = profile;
    return profile;
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final fbUser = userCredential.user;
    if (fbUser == null) {
      throw Exception('Authentication failed: No user returned.');
    }

    var profile = await fetchUserProfile(fbUser.uid);

    // If profile document does not exist, provision default unprivileged profile
    if (profile == null) {
      final now = DateTime.now();
      profile = UserProfile(
        uid: fbUser.uid,
        email: fbUser.email ?? email.trim(),
        displayName: fbUser.displayName ?? 'Medical Staff',
        role: UserRole.doctor, // Safe unprivileged default
        createdAt: now,
        updatedAt: now,
      );
      await _firestore.collection('users').doc(fbUser.uid).set(profile.toMap());
    }

    _cachedProfile = profile;
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _cachedProfile = null;
  }
}
