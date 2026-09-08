import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../theme/register_theme.dart';
import '../utils/freshness.dart';
import '../widgets/admin_action.dart';
import '../widgets/register.dart';

/// Location is a field on the record like any other: it is only filled in by
/// members who switched sharing on, and it carries how old the reading is.
class MapScreen extends StatefulWidget {
  final String profileId;

  const MapScreen({super.key, required this.profileId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _order = ['bunda', 'aku', 'adek'];

  Future<void> _toggleMySharing(bool enabled) async {
    await FirestoreService.instance.setLocationSharing(widget.profileId, enabled);
    if (enabled) {
      await LocationService.instance.startSharing(widget.profileId);
    } else {
      await LocationService.instance.stopSharing();
    }
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
          final onMap =
              profiles.where((p) => p.hasLocation && p.locationSharingEnabled);

          final markers = onMap
              .map((p) => Marker(
                    markerId: MarkerId(p.id),
                    position: LatLng(p.lastLatitude!, p.lastLongitude!),
                    infoWindow: InfoWindow(title: p.name),
                  ))
              .toSet();

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
              SizedBox(
                height: 320,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline),
                      color: scheme.surface,
                    ),
                    child: markers.isEmpty
                        ? const RegisterEmpty(
                            'Belum ada yang membagikan lokasi.\nNyalakan sakelar di '
                            'atas kalau kamu mau terlihat di peta.',
                          )
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: markers.first.position,
                              zoom: 12,
                            ),
                            markers: markers,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final int number;
  final Profile profile;
  final bool isMe;
  final bool last;

  const _LocationRow({
    required this.number,
    required this.profile,
    required this.isMe,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = RegisterInk.forMember(context, profile.id);
    final sharing = profile.locationSharingEnabled;
    final fresh = freshnessOf(profile.lastLocationAt);

    return Container(
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
            child: Align(
              alignment: Alignment.centerRight,
              child: sharing && profile.hasLocation
                  ? StampField(
                      value: 'di peta',
                      ink: ink,
                      freshness: fresh,
                    )
                  : FieldLabel(
                      sharing ? 'menunggu sinyal' : 'tidak dibagikan',
                      color: scheme.onSurfaceVariant,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
