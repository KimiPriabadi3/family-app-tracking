import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_plan.dart';

/// Raises notifications on this device. There is no server pushing them — the
/// periodic check decides what to show and calls in here.
///
/// Swappable so the web demo and the golden renders can substitute a no-op
/// rather than reaching for a plugin that does not exist there.
class NotificationService {
  static NotificationService instance = NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Set when a notification tap launched or resumed the app, so the UI can
  /// open the tab the notification was about.
  static final ValueNotifier<String?> pendingPayload = ValueNotifier(null);

  /// One channel per kind, named in Indonesian, so the family can mute just
  /// the chore reminder in Android settings without losing the shopping list.
  static const _channels = <NotifKind, ({String id, String name, String desc})>{
    NotifKind.errand: (
      id: 'titip_beli',
      name: 'Titip beli',
      desc: 'Ada yang menitip barang di daftar belanja',
    ),
    NotifKind.announcement: (
      id: 'pengumuman',
      name: 'Pengumuman',
      desc: 'Pengumuman baru di papan keluarga',
    ),
    NotifKind.cancelledEvent: (
      id: 'jadwal',
      name: 'Jadwal dibatalkan',
      desc: 'Ada jadwal keluarga yang dibatalkan',
    ),
    NotifKind.chore: (
      id: 'piket',
      name: 'Piket rumah',
      desc: 'Pengingat giliran piket tiap Senin pagi',
    ),
    NotifKind.arrival: (
      id: 'kedatangan',
      name: 'Ada yang sampai',
      desc: 'Anggota keluarga tiba di rumah, kampus, atau kantor',
    ),
  };

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        pendingPayload.value = response.payload;
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in _channels.values) {
      await android?.createNotificationChannel(AndroidNotificationChannel(
        channel.id,
        channel.name,
        description: channel.desc,
        importance: Importance.defaultImportance,
      ));
    }
  }

  Future<bool> permissionGranted() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> show(PlannedNotification notification) async {
    final channel = _channels[notification.kind]!;
    await _plugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.desc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: notification.payload,
    );
  }

  /// A tap that launched the app cold does not go through the callback above.
  Future<void> consumeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      pendingPayload.value = details?.notificationResponse?.payload;
    }
  }
}
