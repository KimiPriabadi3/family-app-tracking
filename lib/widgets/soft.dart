import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/freshness.dart';

/// A rounded, softly shadowed panel. Everything on a screen sits in one.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SoftCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
    this.padding = const EdgeInsets.all(6),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.card);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: softShadow(context),
      ),
      // Material rather than a plain box so ripples and list-tile backgrounds
      // inside a card actually paint.
      child: Material(
        color: color ?? scheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A quiet heading above a card, with an icon so a section can be found by
/// shape as well as by reading.
class SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const SectionHeading({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// A member's initial in their own colour. Used everywhere a person appears,
/// so colour alone tells you whose thing this is.
class MemberAvatar extends StatelessWidget {
  final String profileId;
  final String name;
  final double size;

  const MemberAvatar({
    super.key,
    required this.profileId,
    required this.name,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forMember(context, profileId);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// A rounded pill carrying a status or a label.
class SoftPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  const SoftPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 12 : 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
          ],
          // Place names are the member's own now, and "Di Bimbel Primagama
          // Cabang Bekasi" has to end in an ellipsis rather than overflow.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The status pill plus how long ago it was set. Aged entries fade and, once
/// stale, say so plainly rather than quietly looking current.
class StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Freshness freshness;

  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.freshness,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final faded = color.withValues(alpha: freshness.inkOpacity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedScale(
          scale: 1,
          duration: const Duration(milliseconds: 250),
          child: SoftPill(text: label, color: faded, icon: icon),
        ),
        if (freshness.isStale) ...[
          const SizedBox(height: 5),
          Text(
            'belum diperbarui',
            style: TextStyle(fontSize: 11, color: scheme.error),
          ),
        ],
      ],
    );
  }
}

/// Empty states get a friendly line and a shape, never a bare sentence on the
/// background.
class SoftEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const SoftEmpty({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
