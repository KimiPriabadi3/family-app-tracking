import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/freshness.dart';
import '../utils/relative_time.dart';
import '../widgets/admin_action.dart';
import '../widgets/soft.dart';

/// Where everyone is, for the members who chose to share. Tiles come from
/// OpenStreetMap, so there is no API key in the app for anyone to steal.
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
        title: const Text('Peta'),
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
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            children: [
              SoftCard(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card - 6),
                      child: SizedBox(
                        height: 300,
                        child: onMap.isEmpty
                            ? const SoftEmpty(
                                icon: Icons.location_off_rounded,
                                message:
                                    'Belum ada yang membagikan lokasi.\nNyalakan sakelar di bawah kalau kamu mau terlihat.',
                              )
                            : _FamilyMap(
                                controller: _controller, members: onMap),
                      ),
                    ),
                  ],
                ),
              ),
              for (final p in profiles)
                _LocationCard(
                  profile: p,
                  isMe: p.id == widget.profileId,
                  onShow: p.hasLocation && p.locationSharingEnabled
                      ? () => _controller.move(
                            LatLng(p.lastLatitude!, p.lastLongitude!),
                            15,
                          )
                      : null,
                ),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  title: Text(
                    'Bagikan lokasiku',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Terkirim saat aplikasi dibuka dan saat kamu tiba atau pergi dari '
                    'tempatmu. Tidak dipantau terus-menerus.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  value: me?.locationSharingEnabled ?? false,
                  onChanged: _toggleMySharing,
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
                width: 54,
                height: 54,
                child: Opacity(
                  opacity: freshnessOf(p.lastLocationAt).inkOpacity,
                  child: _MemberPin(profile: p),
                ),
              ),
          ],
        ),
        // Required by the OpenStreetMap tile usage policy.
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberPin extends StatelessWidget {
  final Profile profile;

  const _MemberPin({required this.profile});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forMember(context, profile.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 6),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Profile profile;
  final bool isMe;
  final VoidCallback? onShow;

  const _LocationCard({
    required this.profile,
    required this.isMe,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sharing = profile.locationSharingEnabled;
    final fresh = freshnessOf(profile.lastLocationAt);
    final color = AppColors.forMember(context, profile.id);

    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onShow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              MemberAvatar(
                profileId: profile.id,
                name: profile.name,
                size: 40,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '${profile.name} (kamu)' : profile.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      !sharing
                          ? 'Tidak berbagi lokasi'
                          : profile.hasLocation
                              ? fresh == Freshness.fresh
                                  ? 'Diperbarui ${formatRelativeTime(profile.lastLocationAt!)}'
                                  : 'Lokasi terakhir ${formatRelativeTime(profile.lastLocationAt!)} '
                                      '— mungkin sudah tidak akurat'
                              : 'Menunggu sinyal',
                      style: TextStyle(
                        fontSize: 13,
                        color: fresh.isStale && sharing && profile.hasLocation
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onShow != null)
                SoftPill(
                  text: 'Lihat',
                  color: color,
                  icon: Icons.my_location_rounded,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
