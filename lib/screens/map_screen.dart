import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../theme/register_theme.dart';
import '../utils/freshness.dart';
import '../widgets/admin_action.dart';
import '../widgets/register.dart';

/// Location is a field on the record like any other: filled in only by members
/// who switched sharing on, and carrying how old the reading is.
///
/// Tiles come from OpenStreetMap, which needs no API key and no billing
/// account — so the published APK carries no credential worth stealing.
class MapScreen extends StatefulWidget {
  final String profileId;

  const MapScreen({super.key, required this.profileId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _order = ['bunda', 'aku', 'adek'];

  final _controller = MapController();

  Future<void> _toggleMySharing(bool enabled) async {
    await FirestoreService.instance.setLocationSharing(widget.profileId, enabled);
    if (enabled) {
      await LocationService.instance.startSharing(widget.profileId);
    } else {
      await LocationService.instance.stopSharing();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PETA'),
        actions: [AdminAction(profileId: widget.profileId)],
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byId = {for (final p in snapshot.data!) p.id: p};
          final profiles = [
            for (final id in _order)
              if (byId[id] != null) byId[id]!,
          ];
          final me = byId[widget.profileId];
          final onMap = profiles
              .where((p) => p.hasLocation && p.locationSharingEnabled)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              RegisterSheet(
                child: Column(
                  children: [
                    const RegisterHeaderStrip(
                      columns: ['No.', 'Nama', 'Berbagi lokasi'],
                      flex: [1, 3, 4],
                    ),
                    for (var i = 0; i < profiles.length; i++)
                      _LocationRow(
                        number: i + 1,
                        profile: profiles[i],
                        isMe: profiles[i].id == widget.profileId,
                        last: i == profiles.length - 1,
                        onShow: profiles[i].hasLocation &&
                                profiles[i].locationSharingEnabled
                            ? () => _controller.move(
                                  LatLng(profiles[i].lastLatitude!,
                                      profiles[i].lastLongitude!),
                                  15,
                                )
                            : null,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Bagikan lokasiku',
                    style: RegisterType.value.copyWith(color: scheme.onSurface),
                  ),
                  subtitle: Text(
                    'Hanya selagi aplikasi ini terbuka. Tidak ada pelacakan di '
                    'latar belakang.',
                    style: RegisterType.annotation
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  value: me?.locationSharingEnabled ?? false,
                  onChanged: _toggleMySharing,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  height: 340,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outline),
                    color: scheme.surface,
                  ),
                  child: onMap.isEmpty
                      ? const RegisterEmpty(
                          'Belum ada yang membagikan lokasi.\nNyalakan sakelar di '
                          'atas kalau kamu mau terlihat di peta.',
                        )
                      : _FamilyMap(controller: _controller, members: onMap),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FamilyMap extends StatelessWidget {
  final MapController controller;
  final List<Profile> members;

  const _FamilyMap({required this.controller, required this.members});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter:
            LatLng(members.first.lastLatitude!, members.first.lastLongitude!),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.keluarga.family_app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final p in members)
              Marker(
                point: LatLng(p.lastLatitude!, p.lastLongitude!),
                width: 96,
                height: 34,
                child: _MemberPin(profile: p),
              ),
          ],
        ),
        // Required by the OpenStreetMap tile usage policy.
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            color: scheme.surface.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              '© OpenStreetMap contributors',
              style: RegisterType.annotation.copyWith(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A name plate in the member's own ink rather than a generic pin, so the map
/// reads with the same key as every other sheet in the register.
class _MemberPin extends StatelessWidget {
  final Profile profile;

  const _MemberPin({required this.profile});

  @override
  Widget build(BuildContext context) {
    final ink = RegisterInk.forMember(context, profile.id);
    final fresh = freshnessOf(profile.lastLocationAt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: ink.withValues(alpha: fresh.inkOpacity),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            profile.name.toUpperCase(),
            style: RegisterType.label.copyWith(color: Colors.white, fontSize: 11),
          ),
        ),
        Container(width: 2, height: 10, color: ink),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  final int number;
  final Profile profile;
  final bool isMe;
  final bool last;
  final VoidCallback? onShow;

  const _LocationRow({
    required this.number,
    required this.profile,
    required this.isMe,
    required this.last,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = RegisterInk.forMember(context, profile.id);
    final sharing = profile.locationSharingEnabled;
    final fresh = freshnessOf(profile.lastLocationAt);

    return InkWell(
      onTap: onShow,
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SerialBand(number: number, ink: ink),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: RegisterType.valueStrong.copyWith(color: ink),
                  ),
                  if (isMe) ...[
                    const SizedBox(height: 2),
                    FieldLabel('barismu', color: scheme.onSurfaceVariant),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (sharing && profile.hasLocation) ...[
                    StampField(value: 'di peta', ink: ink, freshness: fresh),
                    const SizedBox(height: 4),
                    FieldLabel('ketuk untuk lihat', color: scheme.onSurfaceVariant),
                  ] else
                    FieldLabel(
                      sharing ? 'menunggu sinyal' : 'tidak dibagikan',
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
