import 'package:firebase_messaging/firebase_messaging.dart';

/// Thin wrapper around Firebase Cloud Messaging for reminder push
/// notifications (e.g. "giliran kamu piket minggu ini").
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<String?> getToken() => _messaging.getToken();
}
