import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../widgets/admin_action.dart';

class MapScreen extends StatefulWidget {
  final String profileId;

  const MapScreen({super.key, required this.profileId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Keluarga'),
        actions: [AdminAction(profileId: widget.profileId)],
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? const <Profile>[];
          Profile? me;
          for (final p in profiles) {
            if (p.id == widget.profileId) {
              me = p;
              break;
            }
          }
          final sharing = profiles.where((p) => p.hasLocation && p.locationSharingEnabled);

          final markers = sharing
              .map((p) => Marker(
                    markerId: MarkerId(p.id),
                    position: LatLng(p.lastLatitude!, p.lastLongitude!),
                    infoWindow: InfoWindow(title: p.name),
                  ))
              .toSet();

          return Column(
            children: [
              SwitchListTile(
                title: const Text('Bagikan lokasiku'),
                subtitle: const Text('Anggota lain bisa lihat posisimu di peta selagi app dibuka'),
                value: me?.locationSharingEnabled ?? false,
                onChanged: _toggleMySharing,
              ),
              const Divider(height: 1),
              Expanded(
                child: markers.isEmpty
                    ? const Center(child: Text('Belum ada anggota yang membagikan lokasi'))
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: markers.first.position,
                          zoom: 12,
                        ),
                        markers: markers,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
