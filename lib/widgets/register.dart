import 'package:flutter/material.dart';

import '../theme/register_theme.dart';
import '../utils/freshness.dart';

/// A ruled sheet. Structure comes from hairlines and square corners, never
/// from elevation, so nothing here casts a shadow.
class RegisterSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const RegisterSheet({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 12, 12, 0),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }
}

/// Small, tracked, upper case — the way a form prints the name of a field.
class FieldLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const FieldLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: RegisterType.label.copyWith(
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The column header strip that names what each field holds.
class RegisterHeaderStrip extends StatelessWidget {
  final List<String> columns;
  final List<int> flex;

  const RegisterHeaderStrip({super.key, required this.columns, required this.flex});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(
                columns[i].toUpperCase(),
                style: RegisterType.label.copyWith(color: scheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The numbered band at the head of a member's row — one ink per person.
class SerialBand extends StatelessWidget {
  final int number;
  final Color ink;

  const SerialBand({super.key, required this.number, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      color: ink,
      child: Text(
        '$number',
        style: RegisterType.serial.copyWith(color: Colors.white),
      ),
    );
  }
}

/// A value that was stamped onto the record at a moment in time.
///
/// This is the app's one authored motion: setting a value strikes it onto the
/// page — it lands oversized and rotated, then settles square. Everything
/// else in the interface stays still.
class StampField extends StatefulWidget {
  final String value;
  final Color ink;
  final Freshness freshness;
  final String? trailing;

  const StampField({
    super.key,
    required this.value,
    required this.ink,
    required this.freshness,
    this.trailing,
  });

  @override
  State<StampField> createState() => _StampFieldState();
}

class _StampFieldState extends State<StampField> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  @override
  void didUpdateWidget(StampField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stale = widget.freshness.isStale;
    final ink = widget.ink.withValues(alpha: widget.freshness.inkOpacity);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutExpo.transform(_controller.value);
        return Transform.rotate(
          angle: (1 - t) * -0.06,
          child: Transform.scale(scale: 1 + (1 - t) * 0.55, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: ink, width: 2)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Stack(
          children: [
            if (stale)
              Positioned.fill(
                child: CustomPaint(
                  painter: HatchPainter(color: ink.withValues(alpha: 0.35)),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.value.toUpperCase(),
                  style: RegisterType.label.copyWith(color: ink, fontSize: 12),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.trailing!,
                    style: RegisterType.annotation.copyWith(color: ink, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An empty field, said in words rather than left blank — a register that
/// shows nothing is indistinguishable from one that failed to load.
class RegisterEmpty extends StatelessWidget {
  final String message;

  const RegisterEmpty(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: scheme.outline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: RegisterType.annotation.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Container(height: 1, color: scheme.outline),
        ],
      ),
    );
  }
}
