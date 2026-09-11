import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/family_place.dart';
import '../services/geofence_service.dart';
import '../services/place_store.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/permission_sheet.dart';
import '../widgets/place_editor_sheet.dart';
import '../widgets/place_icons.dart';
import '../widgets/soft.dart';
import 'place_picker_screen.dart';

/// What a place is before it has coordinates: enough to save it once located.
typedef _PlaceName = ({String id, String name, PlaceIcon icon});

/// Where each member lists the places that should set their status — as many
/// as they need, named however they like. Adek's two tutoring centres are two
/// places, not a squeeze into "Di kampus".
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
  List<FamilyPlace> _places = [];
  bool _autoEnabled = false;
  LocationPermissionLevel _permission = LocationPermissionLevel.none;
  bool _busy = false;
  ({DateTime at, String text})? _lastEvent;

  Color get _color => AppColors.forMember(context, widget.profileId);

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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      body: 'Kalau kamu sampai di salah satu tempatmu, statusmu berubah '
          'tanpa kamu sentuh apa-apa.',
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

  Set<String> _namesExcept(FamilyPlace? place) =>
      {for (final p in _places) if (p.id != place?.id) p.name};

  Future<void> _addPlace() async {
    final draft = await showPlaceEditor(
      context,
      takenNames: _namesExcept(null),
      color: _color,
    );
    if (draft == null) return;
    final _PlaceName place =
        (id: PlaceStore.newId(), name: draft.name, icon: draft.icon);
    if (draft.locate == PlaceLocate.map) {
      await _locateOnMap(place);
    } else {
      await _locateHere(place);
    }
  }

  Future<void> _editPlace(FamilyPlace place) async {
    final draft = await showPlaceEditor(
      context,
      existing: place,
      takenNames: _namesExcept(place),
      color: _color,
    );
    if (draft == null) return;
    await PlaceStore.savePlace(
        place.copyWith(name: draft.name, icon: draft.icon));
    await _load();
  }

  Future<void> _save(
    _PlaceName what, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final existing = await PlaceStore.placeById(what.id);
    await PlaceStore.savePlace(FamilyPlace(
      id: what.id,
      name: what.name,
      icon: what.icon,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: existing?.radiusMeters ?? kDefaultPlaceRadius,
      setAt: DateTime.now(),
      accuracyMeters: accuracyMeters,
    ));
    await GeofenceService.instance.syncGeofences(widget.profileId);
  }

  Future<void> _locateHere(_PlaceName what) async {
    setState(() => _busy = true);
    try {
      if (await GeofenceService.instance.permissionLevel() ==
          LocationPermissionLevel.none) {
        if (!await GeofenceService.instance.requestWhileInUse()) {
          _toast('Izin lokasi dibutuhkan untuk menandai tempat di sini.');
          return;
        }
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

      await _save(
        what,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      // You are standing in it, so this is an arrival: don't make the member
      // leave and come back before anything happens.
      final saved = await PlaceStore.placeById(what.id);
      if (saved != null) {
        await GeofenceService.instance
            .arrivedByMarking(widget.profileId, saved);
      }
      _toast(_autoEnabled
          ? '${what.name} ditandai, dan statusmu sekarang Di ${what.name}.'
          : '${what.name} ditandai. Nyalakan Status otomatis supaya statusmu '
              'berubah sendiri.');
    } catch (_) {
      _toast('Lokasi belum bisa diambil. Pastikan GPS menyala, lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _locateOnMap(_PlaceName what) async {
    final existing = await PlaceStore.placeById(what.id);
    // Start where the answer probably is: the place itself, else another place
    // this member already marked, else wherever the phone last was.
    final anchor = existing ?? (_places.isEmpty ? null : _places.first);
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
        placeName: what.name,
        initialCenter: center,
        initialZoom: zoom,
        radiusMeters: existing?.radiusMeters ?? kDefaultPlaceRadius,
        color: _color,
      ),
    ));
    if (picked == null) return;

    // No accuracy on purpose: no GPS fix was involved, and the card reads its
    // absence to say the place was picked on the map.
    await _save(what, latitude: picked.latitude, longitude: picked.longitude);
    await _load();
    _toast('${what.name} ditandai lewat peta. Kalau kurang pas, tandai ulang '
        'saat kamu sedang di sana.');
  }

  Future<void> _removePlace(FamilyPlace place) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${place.name}?'),
        content: Text(
          'Statusmu tidak akan berubah sendiri di ${place.name} lagi.',
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
    await PlaceStore.removePlace(place.id);
    await GeofenceService.instance.syncGeofences(widget.profileId);
    await _load();
  }

  Future<void> _setRadius(FamilyPlace place, int radius) async {
    await PlaceStore.savePlace(place.copyWith(radiusMeters: radius));
    await GeofenceService.instance.syncGeofences(widget.profileId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsPermission =
        _autoEnabled && _permission != LocationPermissionLevel.always;
    final full = _places.length >= kMaxPlaces;

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
              if (_places.isEmpty)
                const SoftCard(
                  padding: EdgeInsets.symmetric(vertical: 28, horizontal: 18),
                  child: SoftEmpty(
                    icon: Icons.add_location_alt_rounded,
                    message: 'Belum ada tempat.\nTambahkan rumah, sekolah, '
                        'tempat les, atau tempat lain yang sering kamu datangi.',
                  ),
                ),
              for (final place in _places)
                _PlaceCard(
                  key: ValueKey(place.id),
                  place: place,
                  color: _color,
                  onEdit: () => _editPlace(place),
                  onMarkHere: () => _locateHere(
                      (id: place.id, name: place.name, icon: place.icon)),
                  onPickOnMap: () => _locateOnMap(
                      (id: place.id, name: place.name, icon: place.icon)),
                  onRemove: () => _removePlace(place),
                  onRadius: (r) => _setRadius(place, r),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: full ? null : _addPlace,
                    icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                    label: Text(full
                        ? 'Sudah $kMaxPlaces tempat, hapus satu dulu'
                        : 'Tambah tempat'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatefulWidget {
  final FamilyPlace place;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onMarkHere;
  final VoidCallback onPickOnMap;
  final VoidCallback onRemove;
  final ValueChanged<int> onRadius;

  const _PlaceCard({
    super.key,
    required this.place,
    required this.color,
    required this.onEdit,
    required this.onMarkHere,
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
    if (oldWidget.place.radiusMeters != widget.place.radiusMeters) {
      _dragging = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = widget.place;
    final color = widget.color;
    final radius = _dragging?.round() ?? place.radiusMeters;
    final point = LatLng(place.latitude, place.longitude);

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
                child: Icon(placeIconData(place.icon), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Radius $radius m · '
                      '${place.pickedOnMap ? 'dipilih di peta' : 'ditandai'} '
                      '${formatRelativeTime(place.setAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onEdit,
                child: const Text('Ubah'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: SizedBox(
              height: 140,
              child: FlutterMap(
                // Keyed by position so re-marking recentres the preview.
                key: ValueKey('${place.latitude},${place.longitude}'),
                options: MapOptions(
                  initialCenter: point,
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
                        point: point,
                        radius: radius.toDouble(),
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
            value: _dragging ?? place.radiusMeters.toDouble(),
            min: kMinPlaceRadius.toDouble(),
            max: kMaxPlaceRadius.toDouble(),
            divisions: (kMaxPlaceRadius - kMinPlaceRadius) ~/ 25,
            label: '$radius m',
            onChanged: (value) => setState(() => _dragging = value),
            onChangeEnd: (value) => widget.onRadius(value.round()),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onMarkHere,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  label: const Text('Tandai ulang di sini'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onRemove,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: const Text('Hapus'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onPickOnMap,
              icon: const Icon(Icons.map_rounded, size: 20),
              label: const Text('Ubah lewat peta'),
            ),
          ),
        ],
      ),
    );
  }
}
