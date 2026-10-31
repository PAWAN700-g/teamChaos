import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../models/telemetry_model.dart';
import '../models/security_alert_model.dart';
import 'api_service.dart';

/// Reactive Firestore Stream Service.
/// Enables Flutter UI to listen to live authorized Firestore collections:
/// - Dashboard summaries (/dashboard_summaries/current)
/// - Registered medical devices (/devices)
/// - Verified, decrypted telemetry streams (/telemetry)
/// - Detected cybersecurity SIEM alerts (/security_alerts)
///
/// If Firebase Core is not initialized (e.g. offline unit testing or local prototype),
/// cleanly returns empty streams without leaking timers.
class FirestoreStreamService {
  final FirebaseFirestore? firestore;

  FirestoreStreamService({
    this.firestore,
    ApiService? apiService,
  });

  FirebaseFirestore? get _firestore => firestore;

  bool get isFirestoreAvailable => _firestore != null;

  /// Listen to live aggregated dashboard summary.
  Stream<Map<String, dynamic>?> streamDashboardSummary() {
    final fs = _firestore;
    if (fs != null) {
      try {
        return fs
            .collection('dashboard_summaries')
            .doc('current')
            .snapshots()
            .map((doc) => doc.exists ? doc.data() : null)
            .handleError((error) {
          debugPrint('[FirestoreStreamService] Summary stream notice: $error');
          return null;
        });
      } catch (e) {
        debugPrint('[FirestoreStreamService] Firestore summary listener error: $e');
      }
    }
    return const Stream.empty();
  }

  /// Listen to authorized medical devices.
  Stream<List<DeviceModel>> streamDevices() {
    final fs = _firestore;
    if (fs != null) {
      try {
        return fs
            .collection('devices')
            .snapshots()
            .map((snapshot) {
              return snapshot.docs.map((doc) {
                final data = doc.data();
                return DeviceModel.fromJson(data);
              }).toList();
            })
            .handleError((error) {
              debugPrint('[FirestoreStreamService] Devices stream error: $error');
              return <DeviceModel>[];
            });
      } catch (e) {
        debugPrint('[FirestoreStreamService] Could not attach devices listener: $e');
      }
    }
    return const Stream.empty();
  }

  /// Listen to verified telemetry packets published by the backend authority.
  Stream<List<TelemetryModel>> streamVerifiedTelemetry({String? deviceId}) {
    final fs = _firestore;
    if (fs != null) {
      try {
        Query<Map<String, dynamic>> query = fs.collection('telemetry');
        if (deviceId != null && deviceId.isNotEmpty) {
          query = query.where('device_id', isEqualTo: deviceId);
        }
        return query.limit(50).snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            return TelemetryModel.fromJson(doc.data());
          }).toList();
        }).handleError((error) {
          debugPrint('[FirestoreStreamService] Telemetry stream error: $error');
          return <TelemetryModel>[];
        });
      } catch (e) {
        debugPrint('[FirestoreStreamService] Could not attach telemetry listener: $e');
      }
    }
    return const Stream.empty();
  }

  /// Listen to detected security alerts published by backend detection routines.
  Stream<List<SecurityAlertModel>> streamSecurityAlerts() {
    final fs = _firestore;
    if (fs != null) {
      try {
        return fs
            .collection('security_alerts')
            .limit(50)
            .snapshots()
            .map((snapshot) {
              return snapshot.docs.map((doc) {
                return SecurityAlertModel.fromJson(doc.data());
              }).toList();
            })
            .handleError((error) {
              debugPrint('[FirestoreStreamService] Alerts stream error: $error');
              return <SecurityAlertModel>[];
            });
      } catch (e) {
        debugPrint('[FirestoreStreamService] Could not attach alerts listener: $e');
      }
    }
    return const Stream.empty();
  }
}
