import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/family_place.dart';
import '../models/profile.dart';

/// Marking a place from somewhere else: slide the map until the pin sits on it.
///
/// Standing there is still the more precise option — the phone's own fix lands
/// on the spot you are actually at, while a finger on a map can drift a street
/// away — so this sits beside "mark it here" rather than replacing it.
class PlacePickerScreen extends StatefulWidget {
  final PresenceStatus status;
  final LatLng initialCenter;
  final double initialZoom;
  final int radiusMeters;
  final Color color;

  const PlacePickerScreen({
    super.key,
    required this.status,
    required this.initialCenter,
    required this.initialZoom,
    required this.radiusMeters,
    required this.color,
  });

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  // Only the circle follows the camera, so only the circle rebuilds.
  late final _center = ValueNotifier<LatLng>(widget.initialCenter);

  @override
  void dispose() {
    _center.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = placeNameOf(widget.status);

    return Scaffold(
      appBar: AppBar(title: Text('Pilih $name di peta')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: widget.initialZoom,
                    minZoom: 5,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (camera, _) =>
                        _center.value = camera.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.keluarga.family_app',
                      maxZoom: 19,
                    ),
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _center,
                      builder: (context, center, _) => CircleLayer(
                        circles: [
                          CircleMarker(
                            point: center,
                            radius: widget.radiusMeters.toDouble(),
                            useRadiusInMeter: true,
                            color: widget.color.withValues(alpha: 0.18),
                            borderColor: widget.color,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    ),
                    // Required by the OpenStreetMap tile usage policy.
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '© OpenStreetMap',
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
                // The pin stays still while the map slides under it. The
                // glyph's tip sits 20 px below its centre, hence the lift.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 48,
                        color: widget.color,
                        shadows: const [
                          Shadow(
                            color: Color(0x55000000),
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: scheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Geser peta sampai ujung pin tepat di atas $name. '
                      'Cubit dengan dua jari untuk memperbesar.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, _center.value),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: Text('Jadikan titik ini $name'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
