import 'package:flutter/material.dart';

/// Explains, in the app's own words, what a system permission is for — shown
/// *before* the Android dialog appears.
///
/// Android only lets you ask for some permissions once or twice before it stops
/// showing the dialog at all. Spending one of those attempts on someone who
/// does not yet know why they are being asked is how a feature ends up
/// permanently denied.
Future<bool> showPermissionSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  List<String> points = const [],
  String confirmLabel = 'Lanjut',
  String cancelLabel = 'Nanti saja',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: scheme.primary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final point in points) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(confirmLabel),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(cancelLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
