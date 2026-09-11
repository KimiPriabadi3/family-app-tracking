import 'package:flutter/material.dart';

import '../models/family_place.dart';
import '../services/background_poll.dart';
import '../services/geofence_service.dart';
import '../services/notification_service.dart';
import '../services/notification_state.dart';
import '../services/place_store.dart';
import '../widgets/permission_sheet.dart';
import '../widgets/soft.dart';
import 'places_screen.dart';

/// Per-member settings. Unlike the admin panel, everyone reaches this — places
/// and notifications belong to the person holding the phone.
class SettingsScreen extends StatefulWidget {
  final String profileId;

  const SettingsScreen({super.key, required this.profileId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _notifEnabled = false;
  bool _arrivalsEnabled = true;
  bool _autoEnabled = false;
  int _markedPlaces = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final notif = await NotificationState.enabled();
    final arrivals = await NotificationState.arrivalsEnabled();
    final auto = await PlaceStore.autoStatusEnabled();
    final places = await PlaceStore.places();
    if (!mounted) return;
    setState(() {
      _notifEnabled = notif;
      _arrivalsEnabled = arrivals;
      _autoEnabled = auto;
      _markedPlaces = places.length;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!value) {
      await NotificationState.setEnabled(false);
      await cancelPolling();
      await _load();
      return;
    }

    if (!mounted) return;
    final wantsIt = await showPermissionSheet(
      context,
      icon: Icons.notifications_active_rounded,
      title: 'Kabari aku kalau ada yang penting',
      body: 'Cuma untuk titipan belanja, pengumuman, jadwal yang dibatalkan, '
          'piket Senin pagi, dan kalau ada yang sampai di suatu tempat.',
      points: const [
        'Bisa telat sampai 15 menit — aplikasi ini tidak punya server pendorong pesan',
        'Perubahan status yang diisi manual dan pembaruan lokasi tidak pernah diberitahukan',
      ],
      confirmLabel: 'Nyalakan',
    );
    if (!wantsIt) return;

    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Izin notifikasi ditolak. Bisa dinyalakan lewat pengaturan HP.'),
      ));
      return;
    }

    // Stamp every watermark to now, otherwise switching this on would replay
    // the whole backlog at once.
    await NotificationState.seedWatermarksToNow();
    await NotificationState.setEnabled(true);
    await registerPolling();
    await _load();
  }

  Future<void> _tryNow() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Memeriksa...')));
    final ok = await runFamilyPoll();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Selesai. Kalau ada yang baru, notifikasinya sudah muncul.'
          : 'Pemeriksaan gagal. Coba lagi kalau koneksinya sudah stabil.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          const SectionHeading(
            icon: Icons.auto_awesome_rounded,
            title: 'Status otomatis',
          ),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  title: Text(
                    'Atur tempatku',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    _autoEnabled
                        ? '$_markedPlaces dari ${kPlaceableStatuses.length} tempat sudah ditandai'
                        : 'Belum aktif',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlacesScreen(profileId: widget.profileId),
                    ));
                    await _load();
                  },
                ),
              ],
            ),
          ),
          const SectionHeading(
            icon: Icons.notifications_rounded,
            title: 'Pemberitahuan',
          ),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Beri tahu aku',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Biasanya datang dalam 15–30 menit',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  value: _notifEnabled,
                  onChanged: _toggleNotifications,
                ),
                if (_notifEnabled)
                  SwitchListTile(
                    title: Text(
                      'Kalau ada yang sampai',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Misalnya "Bunda sudah sampai di kantor"',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    value: _arrivalsEnabled,
                    onChanged: (v) async {
                      await NotificationState.setArrivalsEnabled(v);
                      await _load();
                    },
                  ),
              ],
            ),
          ),
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yang diberitahukan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in const [
                  'Titipan belanja baru',
                  'Pengumuman baru',
                  'Jadwal yang dibatalkan',
                  'Pengingat piket Senin pagi',
                  'Ada yang sampai di rumah, kampus, atau kantor',
                ])
                  _Line(icon: Icons.check_rounded, text: item, good: true),
                const SizedBox(height: 14),
                Text(
                  'Yang sengaja tidak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in const [
                  'Perubahan status yang diisi manual',
                  'Pembaruan lokasi',
                  'Centang belanjaan',
                  'Saat ada yang berangkat',
                ])
                  _Line(icon: Icons.close_rounded, text: item, good: false),
                const SizedBox(height: 12),
                Text(
                  'Sengaja dibatasi supaya kamu tidak lelah dan malah mematikan '
                  'semuanya.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeading(
            icon: Icons.help_outline_rounded,
            title: 'Kalau notifikasi tidak muncul',
          ),
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sebagian HP mematikan aplikasi di latar belakang untuk '
                  'menghemat baterai. Kalau itu terjadi, notifikasi dan status '
                  'otomatis ikut berhenti.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final hint in const [
                  'Xiaomi: nyalakan Autostart untuk aplikasi ini',
                  'Samsung: keluarkan dari "Sleeping apps"',
                  'Oppo, Realme, Vivo: izinkan berjalan di latar belakang',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '· $hint',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Dan jangan "force stop" aplikasinya — Android akan mematikan '
                  'semuanya sampai kamu membukanya lagi.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => GeofenceService.instance.openSettings(),
                        child: const Text('Buka pengaturan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _notifEnabled ? _tryNow : null,
                        child: const Text('Coba sekarang'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool good;

  const _Line({required this.icon, required this.text, required this.good});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = good ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: good ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
