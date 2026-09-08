import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/calendar_event.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../widgets/admin_action.dart';

class CalendarScreen extends StatefulWidget {
  final String profileId;

  const CalendarScreen({super.key, required this.profileId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Future<void> _addEvent(List<Profile> profiles) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah jadwal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Judul (misal: Rapat kantor)'),
              autofocus: true,
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
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
    final isAdmin = ProfileSession.isAdmin(widget.profileId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender Keluarga'),
        actions: [AdminAction(profileId: widget.profileId)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEvent(const []),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Profile>>(
              stream: FirestoreService.instance.watchProfiles(),
              builder: (context, profileSnap) {
                final profileNames = {
                  for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
                };
                return StreamBuilder<List<CalendarEvent>>(
                  stream: FirestoreService.instance.watchEventsForDay(_selectedDay),
                  builder: (context, snapshot) {
                    final events = snapshot.data ?? const <CalendarEvent>[];
                    if (events.isEmpty) {
                      return const Center(child: Text('Belum ada jadwal di tanggal ini'));
                    }
                    return ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, i) {
                        final event = events[i];
                        final canCancel = isAdmin || event.ownerProfileId == widget.profileId;
                        return ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(
                            event.title,
                            style: event.cancelled
                                ? const TextStyle(decoration: TextDecoration.lineThrough)
                                : null,
                          ),
                          subtitle: Text(
                            [
                              profileNames[event.ownerProfileId] ?? event.ownerProfileId,
                              if (event.note != null) event.note!,
                              if (event.cancelled) 'Dibatalkan',
                            ].join(' · '),
                          ),
                          trailing: canCancel && !event.cancelled
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_outlined),
                                  tooltip: 'Batalkan',
                                  onPressed: () => FirestoreService.instance.cancelEvent(event.id),
                                )
                              : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
