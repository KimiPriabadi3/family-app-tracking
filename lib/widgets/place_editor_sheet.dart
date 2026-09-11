import 'package:flutter/material.dart';

import '../models/family_place.dart';
import 'place_icons.dart';

/// How a new place gets its coordinates.
enum PlaceLocate { here, map }

class PlaceDraft {
  final String name;
  final PlaceIcon icon;

  /// Null when editing an existing place's name or icon only.
  final PlaceLocate? locate;

  const PlaceDraft(this.name, this.icon, this.locate);
}

/// One-tap starting points. Every family's list is different, so these only
/// fill the form; nothing here is required.
const _suggestions = <(String, PlaceIcon)>[
  ('Rumah', PlaceIcon.home),
  ('Sekolah', PlaceIcon.school),
  ('Kampus', PlaceIcon.campus),
  ('Kantor', PlaceIcon.work),
  ('Bimbel', PlaceIcon.study),
  ('Masjid', PlaceIcon.mosque),
  ('Rumah Nenek', PlaceIcon.family),
];

const int _maxNameLength = 30;

/// Names and pictures a place, and for a new one asks where it is.
Future<PlaceDraft?> showPlaceEditor(
  BuildContext context, {
  FamilyPlace? existing,
  required Set<String> takenNames,
  required Color color,
}) {
  return showModalBottomSheet<PlaceDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlaceEditor(
      existing: existing,
      takenNames: takenNames,
      color: color,
    ),
  );
}

class _PlaceEditor extends StatefulWidget {
  final FamilyPlace? existing;
  final Set<String> takenNames;
  final Color color;

  const _PlaceEditor({
    required this.existing,
    required this.takenNames,
    required this.color,
  });

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late PlaceIcon _icon = widget.existing?.icon ?? PlaceIcon.other;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit(PlaceLocate? locate) {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final unchangedName = widget.existing?.name == name;
    final taken = widget.takenNames
        .map((n) => n.toLowerCase())
        .contains(name.toLowerCase());
    setState(() {
      if (name.isEmpty) {
        _error = 'Beri nama dulu, misalnya "Bimbel Primagama".';
      } else if (taken && !unchangedName) {
        _error = 'Kamu sudah punya tempat bernama "$name".';
      } else {
        _error = null;
      }
    });
    if (_error != null) return;
    Navigator.pop(context, PlaceDraft(name, _icon, locate));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNew ? 'Tambah tempat' : 'Ubah tempat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                maxLength: _maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama tempat',
                  hintText: 'misal: Bimbel Primagama',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_isNew) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (name, icon) in _suggestions)
                      ActionChip(
                        avatar: Icon(placeIconData(icon), size: 18),
                        label: Text(name),
                        onPressed: () => setState(() {
                          _name.text = name;
                          _icon = icon;
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Ikon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final icon in PlaceIcon.values)
                    _IconChoice(
                      icon: icon,
                      selected: icon == _icon,
                      color: widget.color,
                      onTap: () => setState(() => _icon = icon),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Nama tempat terlihat oleh keluarga di statusmu. Titik '
                'lokasinya hanya tersimpan di HP ini.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (_isNew) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _submit(PlaceLocate.here),
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    label: const Text('Tandai di sini'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _submit(PlaceLocate.map),
                    icon: const Icon(Icons.map_rounded, size: 20),
                    label: const Text('Pilih di peta'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _submit(null),
                    child: const Text('Simpan'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final PlaceIcon icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: icon.label,
      child: Tooltip(
        message: icon.label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? color : color.withValues(alpha: 0.12),
            ),
            child: Icon(
              placeIconData(icon),
              size: 22,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
