import 'package:flutter/material.dart';

/// How much a stamped value is still worth believing. A status from this
/// morning must not read the same as one from a minute ago, so the register
/// fades and finally hatches its own entries as they age.
enum Freshness { fresh, recent, aging, stale }

Freshness freshnessOf(DateTime? stampedAt) {
  if (stampedAt == null) return Freshness.stale;
  final age = DateTime.now().difference(stampedAt);
  if (age.inMinutes < 45) return Freshness.fresh;
  if (age.inHours < 4) return Freshness.recent;
  if (age.inHours < 12) return Freshness.aging;
  return Freshness.stale;
}

extension FreshnessX on Freshness {
  /// Ink strength. Stale entries never reach full weight again.
  double get inkOpacity {
    switch (this) {
      case Freshness.fresh:
        return 1;
      case Freshness.recent:
        return 0.86;
      case Freshness.aging:
        return 0.62;
      case Freshness.stale:
        return 0.42;
    }
  }

  bool get isStale => this == Freshness.stale;

  /// Said plainly, because a faded stamp alone is not an answer.
  String get note {
    switch (this) {
      case Freshness.fresh:
        return 'baru';
      case Freshness.recent:
        return 'masih baru';
      case Freshness.aging:
        return 'sudah agak lama';
      case Freshness.stale:
        return 'belum diperbarui';
    }
  }
}

/// Diagonal hatching drawn across a stale field, the way a clerk strikes
/// through an entry that can no longer be relied on.
class HatchPainter extends CustomPainter {
  final Color color;
  final double spacing;

  const HatchPainter({required this.color, this.spacing = 7});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(HatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}
