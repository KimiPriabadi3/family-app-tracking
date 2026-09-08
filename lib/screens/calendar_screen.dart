import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/calendar_event.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/register_theme.dart';
import '../widgets/admin_action.dart';
import '../widgets/register.dart';

/// Commitments entered against a date. A cancelled entry is never deleted from
/// the record — it is struck in stamp red, so everyone can see it was called
/// off rather than never written.
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

  /// table_calendar labels its columns from the device locale, which leaves an
  /// Indonesian household reading "Sun Mon Tue". Named here instead.
  static const _weekdays = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  String _dateLine(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _addEntry(BuildContext context) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ISI ${_dateLine(_selectedDay).toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Urusan',
                hintText: 'misal: rapat kantor',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh dikosongkan)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CATAT'),
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
        title: const Text('KALENDER'),
        actions: [AdminAction(profileId: widget.profileId)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('CATAT'),
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
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  RegisterSheet(
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
                        titleCentered: false,
                        titleTextFormatter: (date, locale) =>
                            '${_months[date.month - 1]} ${date.year}',
                        headerPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        titleTextStyle: RegisterType.label.copyWith(
                          fontSize: 13,
                          color: scheme.onSurface,
                        ),
                        leftChevronIcon:
                            Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
                        rightChevronIcon:
                            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: scheme.outline)),
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        dowTextFormatter: (date, locale) =>
                            _weekdays[date.weekday % 7],
                        weekdayStyle: RegisterType.label
                            .copyWith(fontSize: 10, color: scheme.onSurfaceVariant),
                        weekendStyle: RegisterType.label
                            .copyWith(fontSize: 10, color: scheme.error),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: scheme.outline)),
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        cellMargin: const EdgeInsets.all(5),
                        defaultDecoration: const BoxDecoration(),
                        weekendDecoration: const BoxDecoration(),
                        outsideDecoration: const BoxDecoration(),
                        todayDecoration: BoxDecoration(
                          border: Border.all(color: scheme.primary, width: 1.5),
                        ),
                        selectedDecoration: BoxDecoration(color: scheme.primary),
                        selectedTextStyle: RegisterType.value.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        todayTextStyle: RegisterType.value.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        defaultTextStyle:
                            RegisterType.value.copyWith(color: scheme.onSurface),
                        weekendTextStyle:
                            RegisterType.value.copyWith(color: scheme.error),
                        outsideTextStyle: RegisterType.value.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      calendarBuilders: CalendarBuilders<String>(
                        markerBuilder: (context, day, owners) {
                          if (owners.isEmpty) return null;
                          final seen = owners.toSet().toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final id in seen)
                                  Container(
                                    width: 6,
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    color: RegisterInk.forMember(context, id),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                    child: FieldLabel(
                      'Isi ${_dateLine(_selectedDay)}',
                      color: scheme.onSurfaceVariant,
                    ),
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
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ProfileSession.isAdmin(profileId);

    return StreamBuilder<List<CalendarEvent>>(
      stream: FirestoreService.instance.watchEventsForDay(day),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <CalendarEvent>[];
        if (events.isEmpty) {
          return const RegisterEmpty('Tidak ada urusan tercatat di tanggal ini.');
        }
        return RegisterSheet(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const RegisterHeaderStrip(
                columns: ['Nama', 'Urusan', ''],
                flex: [2, 4, 3],
              ),
              for (var i = 0; i < events.length; i++)
                _EntryRow(
                  event: events[i],
                  ownerName: names[events[i].ownerProfileId] ??
                      events[i].ownerProfileId,
                  canCancel: isAdmin || events[i].ownerProfileId == profileId,
                  last: i == events.length - 1,
                  outline: scheme.outline,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryRow extends StatelessWidget {
  final CalendarEvent event;
  final String ownerName;
  final bool canCancel;
  final bool last;
  final Color outline;

  const _EntryRow({
    required this.event,
    required this.ownerName,
    required this.canCancel,
    required this.last,
    required this.outline,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = RegisterInk.forMember(context, event.ownerProfileId);
    final cancelled = event.cancelled;

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: outline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              ownerName,
              style: RegisterType.label.copyWith(color: ink, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: RegisterType.value.copyWith(
                    color: cancelled ? scheme.error : scheme.onSurface,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                    decorationColor: scheme.error,
                    decorationThickness: 2,
                  ),
                ),
                if (event.note != null && event.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.note!,
                    style: RegisterType.annotation.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (cancelled) ...[
                  const SizedBox(height: 6),
                  FieldLabel('dibatalkan', color: scheme.error),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: canCancel && !cancelled
                ? Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          FirestoreService.instance.cancelEvent(event.id),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('BATALKAN', maxLines: 1),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
