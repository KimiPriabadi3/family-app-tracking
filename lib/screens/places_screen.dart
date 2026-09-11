import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/family_place.dart';
import '../models/profile.dart';
import '../services/geofence_service.dart';
import '../services/place_store.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/permission_sheet.dart';
import '../widgets/soft.dart';
import 'place_picker_screen.dart';
import 'status_screen.dart' show iconForStatus;

/// Where each member marks the places that should set their status.
///
/// The coordinates never leave this phone — see PRODUCT.md. The family only
/// ever sees the resulting status.
class PlacesScreen extends StatefulWidget {
  final String profileId;

  const PlacesScreen({super.key, required this.profileId});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> with WidgetsBindingObserver {
  Map<PresenceStatus, FamilyPlace> _places = {};
  bool _autoEnabled = false;
  LocationPermissionLevel _permission = LocationPermissionLevel.none;
  bool _busy = false;
  ({DateTime at, String text})? _lastEvent;

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
    // Android 11+ sends the user to a settings page rather than showing a
    // dialog, so the answer only arrives when they come back.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final places = await PlaceStore.places();
    final auto = await PlaceStore.autoStatusEnabled();
    final permission = await GeofenceService.instance.permissionLevel();
    final lastEvent = await PlaceStore.lastEvent();
    if (!mounted) return;
    setState(() {
      _places = places;
      _autoEnabled = auto;
      _permission = permission;
      _lastEvent = lastEvent;
    });
  }

  Future<void> _toggleAuto(bool value) async {
    if (!value) {
      await PlaceStore.setAutoStatusEnabled(false);
      await GeofenceService.instance.clearAll();
      await _load();
      return;
    }
    final granted = await _ensureBackgroundPermission();
    await PlaceStore.setAutoStatusEnabled(granted);
    if (granted) {
      await GeofenceService.instance.syncGeofences(widget.profileId);
      await GeofenceService.instance.checkPlacesNow(widget.profileId);
    }
    await _load();
  }

  /// The two-step Android flow, each step explained in our own words first.
  Future<bool> _ensureBackgroundPermission() async {
    final service = GeofenceService.instance;
    if (await service.permissionLevel() == LocationPermissionLevel.always) {
      return true;
    }

    if (!mounted) return false;
    final wantsIt = await showPermissionSheet(
      context,
      icon: Icons.auto_awesome_rounded,
      title: 'Biar statusmu berubah sendiri',
      body: 'Kalau kamu sampai di rumah, statusmu jadi "Di rumah" tanpa kamu '
          'sentuh apa-apa.',
      points: const [
        'Aplikasi cuma dibangunkan saat kamu masuk atau keluar tempat yang kamu tandai',
        'Bukan dipantau terus-menerus, dan tidak ada yang bisa melihat titik lokasinya',
      ],
    );
    if (!wantsIt) return false;

    if (await service.permissionLevel() == LocationPermissionLevel.none) {
      if (!await service.requestWhileInUse()) return false;
    }

    if (!mounted) return false;
    final ready = await showPermissionSheet(
      context,
      icon: Icons.schedule_rounded,
      title: 'Satu izin lagi',
      body: 'Android minta izin terpisah supaya aplikasi boleh tahu lokasimu '
          'walau sedang ditutup. Kamu akan dibawa ke halaman pengaturan — '
          'pilih "Izinkan sepanjang waktu".',
      confirmLabel: 'Buka pengaturan',
      cancelLabel: 'Batal',
    );
    if (!ready) return false;

    await service.requestAlways();
    return await service.permissionLevel() == LocationPermissionLevel.always;
  }

  Future<void> _markHere(PresenceStatus status) async {
    setState(() => _busy = true);
    try {
      if (await GeofenceService.instance.permissionLevel() ==
          LocationPermissionLevel.none) {
        if (!await GeofenceService.instance.requestWhileInUse()) return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (position.accuracy > 50 && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sinyal GPS kurang bagus'),
            content: Text(
              'Posisimu cuma bisa dipastikan sampai sekitar '
              '${position.accuracy.round()} meter. Tandai saja, atau coba lagi '
              'di dekat jendela?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Coba lagi'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Tandai saja'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      await PlaceStore.setPlace(
        status,
        FamilyPlace(
          latitude: position.latitude,
          longitude: position.longitude,
          setAt: DateTime.now(),
          accuracyMeters: position.accuracy,
        ),
      );
      await GeofenceService.instance.syncGeofences(widget.profileId);
      // You are standing in it, so this is an arrival: don't make the member
      // leave and come back before anything happens.
      await GeofenceService.instance.arrivedByMarking(widget.profileId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _autoEnabled
              ? '${status.label} ditandai, dan statusmu sekarang ${status.label}.'
              : '${status.label} ditandai. Nyalakan Status otomatis supaya '
                  'statusmu berubah sendiri.',
        ),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _pickOnMap(PresenceStatus status) async {
    final existing = _places[status];
    // Start where the answer probably is: the place itself, else another place
    // this member already marked, else wherever the phone last was.
    final anchor = existing ?? _places.values.firstOrNull;
    var center = const LatLng(-6.2, 106.8456);
    var zoom = 11.0;
    if (anchor != null) {
      center = LatLng(anchor.latitude, anchor.longitude);
      zoom = 16;
    } else {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          center = LatLng(last.latitude, last.longitude);
          zoom = 15;
        }
      } catch (_) {
        // No permission yet, or no platform support: Jakarta it is.
      }
    }

    if (!mounted) return;
    final picked = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
      builder: (_) => PlacePickerScreen(
        status: status,
        initialCenter: center,
        initialZoom: zoom,
        radiusMeters: existing?.radiusMeters ?? kDefaultPlaceRadius,
        color: AppColors.forMember(context, widget.profileId),
      ),
    ));
    if (picked == null) return;

    await PlaceStore.setPlace(
      status,
      FamilyPlace(
        latitude: picked.latitude,
        longitude: picked.longitude,
        radiusMeters: existing?.radiusMeters ?? kDefaultPlaceRadius,
        setAt: DateTime.now(),
        // Left empty on purpose: no GPS fix was involved, and the card reads
        // this to say the place was picked on the map.
      ),
    );
    await GeofenceService.instance.syncGeofences(widget.profileId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        '${status.label} ditandai lewat peta. Kalau kurang pas, tandai ulang '
        'saat kamu sedang di sana.',
      ),
    ));
  }

  Future<void> _removePlace(PresenceStatus status) async {
    final place = placeNameOf(status);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus tanda $place?'),
        content: Text(
          'Statusmu tidak akan berubah sendiri di $place sampai kamu '
          'menandainya lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await PlaceStore.removePlace(status);
    await GeofenceService.instance.syncGeofences(widget.profileId);
    await _load();
  }

  Future<void> _setRadius(PresenceStatus status, int radius) async {
    final place = _places[status];
    if (place == null) return;
    await PlaceStore.setPlace(status, place.copyWith(radiusMeters: radius));
    await GeofenceService.instance.syncGeofences(widget.profileId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsPermission =
        _autoEnabled && _permission != LocationPermissionLevel.always;

    return Scaffold(
      appBar: AppBar(title: const Text('Tempatku')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                SwitchListTile(
                  title: Text(
                    'Status otomatis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Ubah statusmu sendiri saat kamu sampai di tempat yang kamu tandai',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  value: _autoEnabled,
                  onChanged: _toggleAuto,
                ),
                if (_autoEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastEvent == null
                                ? 'Belum ada kejadian terdeteksi'
                                : 'Terakhir: ${_lastEvent!.text} · '
                                    '${formatRelativeTime(_lastEvent!.at)}',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
              if (needsPermission)
                SoftCard(
                  color: scheme.secondaryContainer,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: scheme.onSecondaryContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Izin lokasi belum cukup',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status otomatis tidak akan jalan kalau aplikasi ditutup. '
                        'Pilih "Izinkan sepanjang waktu" di pengaturan lokasi.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => GeofenceService.instance.openSettings(),
                        child: const Text('Buka pengaturan'),
                      ),
                    ],
                  ),
                ),
              for (final status in kPlaceableStatuses)
                _PlaceCard(
                  status: status,
                  place: _places[status],
                  profileId: widget.profileId,
                  onMark: () => _markHere(status),
                  onPickOnMap: () => _pickOnMap(status),
                  onRemove: () => _removePlace(status),
                  onRadius: (r) => _setRadius(status, r),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Kalau kamu ubah status sendiri, aplikasi tidak akan menimpanya '
                  'selama 8 jam — kecuali kamu terdeteksi pergi dari tempat itu.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            ColoredBox(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatefulWidget {
  final PresenceStatus status;
  final FamilyPlace? place;
  final String profileId;
  final VoidCallback onMark;
  final VoidCallback onPickOnMap;
  final VoidCallback onRemove;
  final ValueChanged<int> onRadius;

  const _PlaceCard({
    required this.status,
    required this.place,
    required this.profileId,
    required this.onMark,
    required this.onPickOnMap,
    required this.onRemove,
    required this.onRadius,
  });

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard> {
  /// The radius under the thumb while dragging. Saving on every tick would
  /// re-register the geofences dozens of times, so only the release is saved,
  /// but the thumb, the circle and the label still have to follow the finger.
  double? _dragging;

  @override
  void didUpdateWidget(_PlaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place?.radiusMeters != widget.place?.radiusMeters) {
      _dragging = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.forMember(context, widget.profileId);
    final marked = widget.place;
    final status = widget.status;
    final radius = _dragging?.round() ?? marked?.radiusMeters;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconForStatus(status), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (marked == null)
                      SoftPill(
                        text: 'Belum ditandai',
                        color: scheme.error,
                        icon: Icons.location_off_rounded,
                      )
                    else
                      Text(
                        'Radius $radius m · '
                        '${marked.accuracyMeters == null ? 'dipilih di peta' : 'ditandai'} '
                        '${formatRelativeTime(marked.setAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (marked != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: SizedBox(
                height: 140,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(marked.latitude, marked.longitude),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.keluarga.family_app',
                      maxZoom: 19,
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(marked.latitude, marked.longitude),
                          radius: radius!.toDouble(),
                          useRadiusInMeter: true,
                          color: color.withValues(alpha: 0.20),
                          borderColor: color,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Slider(
              value: _dragging ?? marked.radiusMeters.toDouble(),
              min: kMinPlaceRadius.toDouble(),
              max: kMaxPlaceRadius.toDouble(),
              divisions: (kMaxPlaceRadius - kMinPlaceRadius) ~/ 25,
              label: '$radius m',
              onChanged: (value) => setState(() => _dragging = value),
              onChangeEnd: (value) => widget.onRadius(value.round()),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onMark,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  label: Text(
                    marked == null
                        ? 'Jadikan lokasi ini ${placeNameOf(status)}'
                        : 'Tandai ulang di sini',
                  ),
                ),
              ),
              if (marked != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onRemove,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('Hapus'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onPickOnMap,
              icon: const Icon(Icons.map_rounded, size: 20),
              label: Text(marked == null ? 'Pilih di peta' : 'Ubah lewat peta'),
            ),
          ),
        ],
      ),
    );
  }
}
