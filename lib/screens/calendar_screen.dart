import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/calendar_event.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_action.dart';
import '../widgets/soft.dart';

/// Everyone's commitments on a shared calendar. A cancelled plan stays on the
/// day, struck through, so "batal" never looks the same as "never happened".
class CalendarScreen extends StatefulWidget {
  final String profileId;

  const CalendarScreen({super.key, required this.profileId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// table_calendar names its columns from the device locale, which would
  /// leave an Indonesian household reading "Sun Mon Tue".
  static const _weekdays = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  String _dateLine(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _addEntry(BuildContext context) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_dateLine(_selectedDay)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ada urusan apa?',
                hintText: 'misal: rapat kantor',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh dilewati)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved != true || titleController.text.trim().isEmpty) return;

    await FirestoreService.instance.addEvent(CalendarEvent(
      id: '',
      ownerProfileId: widget.profileId,
      date: _selectedDay,
      title: titleController.text.trim(),
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [AdminAction(profileId: widget.profileId)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context),
        icon: const Icon(Icons.edit_calendar_rounded),
        label: const Text('Catat'),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final names = {
            for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
          };
          return StreamBuilder<List<CalendarEvent>>(
            stream: FirestoreService.instance.watchAllUpcomingEvents(),
            builder: (context, upcomingSnap) {
              final marks = <DateTime, List<String>>{};
              for (final e in upcomingSnap.data ?? const <CalendarEvent>[]) {
                if (e.cancelled) continue;
                final key = DateTime(e.date.year, e.date.month, e.date.day);
                (marks[key] ??= []).add(e.ownerProfileId);
              }

              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    child: TableCalendar<String>(
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                      eventLoader: (day) =>
                          marks[DateTime(day.year, day.month, day.day)] ?? const [],
                      onDaySelected: (selected, focused) => setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      }),
                      availableGestures: AvailableGestures.horizontalSwipe,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextFormatter: (date, locale) =>
                            '${_months[date.month - 1]} ${date.year}',
                        titleTextStyle: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        leftChevronIcon: Icon(Icons.chevron_left_rounded,
                            color: scheme.onSurfaceVariant),
                        rightChevronIcon: Icon(Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        dowTextFormatter: (date, locale) =>
                            _weekdays[date.weekday % 7],
                        weekdayStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                        weekendStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        cellMargin: const EdgeInsets.all(4),
                        todayDecoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        todayTextStyle: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        defaultTextStyle:
                            TextStyle(color: scheme.onSurface, fontSize: 15),
                        weekendTextStyle:
                            TextStyle(color: scheme.primary, fontSize: 15),
                        outsideTextStyle: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders<String>(
                        markerBuilder: (context, day, owners) {
                          if (owners.isEmpty) return null;
                          final seen = owners.toSet().toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final id in seen)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.forMember(context, id),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SectionHeading(
                    icon: Icons.event_note_rounded,
                    title: _dateLine(_selectedDay),
                  ),
                  _DayEntries(
                    day: _selectedDay,
                    profileId: widget.profileId,
                    names: names,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DayEntries extends StatelessWidget {
  final DateTime day;
  final String profileId;
  final Map<String, String> names;

  const _DayEntries({
    required this.day,
    required this.profileId,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = ProfileSession.isAdmin(profileId);

    return StreamBuilder<List<CalendarEvent>>(
      stream: FirestoreService.instance.watchEventsForDay(day),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <CalendarEvent>[];
        if (events.isEmpty) {
          return const SoftEmpty(
            icon: Icons.event_available_rounded,
            message: 'Tidak ada urusan tercatat di tanggal ini.',
          );
        }
        return Column(
          children: [
            for (final event in events)
              _EntryCard(
                event: event,
                ownerName:
                    names[event.ownerProfileId] ?? event.ownerProfileId,
                canCancel: isAdmin || event.ownerProfileId == profileId,
              ),
          ],
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  final CalendarEvent event;
  final String ownerName;
  final bool canCancel;

  const _EntryCard({
    required this.event,
    required this.ownerName,
    required this.canCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cancelled = event.cancelled;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(
            profileId: event.ownerProfileId,
            name: ownerName,
            size: 40,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cancelled
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ownerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forMember(context, event.ownerProfileId),
                  ),
                ),
                if (event.note != null && event.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.note!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (cancelled) ...[
                  const SizedBox(height: 10),
                  SoftPill(
                    text: 'Dibatalkan',
                    color: scheme.error,
                    icon: Icons.cancel_rounded,
                  ),
                ],
              ],
            ),
          ),
          if (canCancel && !cancelled)
            TextButton(
              onPressed: () => FirestoreService.instance.cancelEvent(event.id),
              child: const Text('Batalkan'),
            ),
        ],
      ),
    );
  }
}
