@Tags(['preview'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_app/models/announcement.dart';
import 'package:family_app/models/calendar_event.dart';
import 'package:family_app/models/errand_item.dart';
import 'package:family_app/models/job_assignment.dart';
import 'package:family_app/models/job_template.dart';
import 'package:family_app/models/profile.dart';
import 'package:family_app/screens/admin_screen.dart';
import 'package:family_app/screens/announcement_screen.dart';
import 'package:family_app/screens/calendar_screen.dart';
import 'package:family_app/screens/errand_list_screen.dart';
import 'package:family_app/screens/map_screen.dart';
import 'package:family_app/screens/profile_select_screen.dart';
import 'package:family_app/screens/status_screen.dart';
import 'package:family_app/screens/tasks_screen.dart';
import 'package:family_app/services/firestore_service.dart';
import 'package:family_app/theme/register_theme.dart';

/// Renders every screen against canned data so the design can be reviewed
/// without a device attached. Run with:
///
///     flutter test --update-goldens test/design_preview_test.dart
///
/// and open the PNGs under test/preview/.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUpAll(() async {
    await _loadFont('Roboto', [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['materialicons-regular.otf']);
    FirestoreService.instance = _CannedFirestore(now: now, today: today);

    // flutter_map asks path_provider for a tile cache directory, which has no
    // implementation in a widget test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  Future<void> preview(
    WidgetTester tester,
    String name,
    Widget screen,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRegisterTheme(brightness: Brightness.light),
      home: screen,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview/$name.png'),
    );
  }

  testWidgets('01 pilih baris', (t) => preview(t, '01-pilih-baris', const ProfileSelectScreen()));
  testWidgets('02 kartu keluarga', (t) => preview(t, '02-kartu-keluarga', const StatusScreen(profileId: 'aku')));
  testWidgets('03 kalender', (t) => preview(t, '03-kalender', const CalendarScreen(profileId: 'aku')));
  testWidgets('04 pengumuman', (t) => preview(t, '04-pengumuman', const AnnouncementScreen(profileId: 'aku')));
  testWidgets('05 piket', (t) => preview(t, '05-piket', const TasksScreen(profileId: 'aku')));
  testWidgets('06 titip beli', (t) => preview(t, '06-titip-beli', const _ErrandHost()));
  testWidgets('07 peta', (t) => preview(t, '07-peta', const MapScreen(profileId: 'aku')));
  testWidgets('08 admin', (t) => preview(t, '08-admin', const AdminScreen(profileId: 'aku')));

  testWidgets('09 kartu keluarga gelap', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRegisterTheme(brightness: Brightness.dark),
      home: const StatusScreen(profileId: 'aku'),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview/09-kartu-keluarga-gelap.png'),
    );
  });
}

/// Titip Beli is a tab body, so it needs a host to render standalone.
class _ErrandHost extends StatelessWidget {
  const _ErrandHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TUGAS · TITIP BELI')),
      body: const ErrandListScreen(profileId: 'aku'),
    );
  }
}

Future<void> _loadFont(String family, List<String> files) async {
  const dir = r'C:\src\flutter\bin\cache\artifacts\material_fonts';
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('$dir\\$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

class _CannedFirestore extends FirestoreService {
  final DateTime now;
  final DateTime today;

  _CannedFirestore({required this.now, required this.today});

  late final List<Profile> _profiles = [
    Profile(
      id: 'bunda',
      name: 'Bunda',
      isAdmin: false,
      status: PresenceStatus.home,
      statusNote: 'Masak dulu, nanti ke pasar',
      statusUpdatedAt: now.subtract(const Duration(minutes: 8)),
      locationSharingEnabled: true,
      lastLatitude: -6.2349,
      lastLongitude: 106.9896,
      lastLocationAt: now.subtract(const Duration(minutes: 6)),
    ),
    Profile(
      id: 'aku',
      name: 'Mas',
      isAdmin: true,
      status: PresenceStatus.campus,
      statusNote: 'Kelas sampai jam 4',
      statusUpdatedAt: now.subtract(const Duration(hours: 3)),
    ),
    Profile(
      id: 'adek',
      name: 'Adek',
      isAdmin: false,
      status: PresenceStatus.office,
      statusUpdatedAt: now.subtract(const Duration(hours: 20)),
    ),
  ];

  @override
  Stream<List<Profile>> watchProfiles() => Stream.value(_profiles);

  @override
  Stream<List<CalendarEvent>> watchEventsForDay(DateTime day) => Stream.value([
        CalendarEvent(
          id: 'e1',
          ownerProfileId: 'bunda',
          date: today,
          title: 'Arisan RT',
          note: 'Di rumah Bu Tuti, jam 4 sore',
          createdAt: now,
        ),
        CalendarEvent(
          id: 'e2',
          ownerProfileId: 'aku',
          date: today,
          title: 'Rapat kantor',
          cancelled: true,
          createdAt: now,
        ),
        CalendarEvent(
          id: 'e3',
          ownerProfileId: 'adek',
          date: today,
          title: 'Les matematika',
          createdAt: now,
        ),
      ]);

  @override
  Stream<List<CalendarEvent>> watchAllUpcomingEvents() => Stream.value([
        CalendarEvent(
          id: 'e1',
          ownerProfileId: 'bunda',
          date: today,
          title: 'Arisan RT',
          createdAt: now,
        ),
        CalendarEvent(
          id: 'e3',
          ownerProfileId: 'adek',
          date: today,
          title: 'Les matematika',
          createdAt: now,
        ),
        CalendarEvent(
          id: 'e4',
          ownerProfileId: 'aku',
          date: today.add(const Duration(days: 2)),
          title: 'Sidang',
          createdAt: now,
        ),
      ]);

  @override
  Stream<List<JobTemplate>> watchJobTemplates() => Stream.value(const [
        JobTemplate(id: 'j1', name: 'Sapu rumah', order: 0),
        JobTemplate(id: 'j2', name: 'Pel rumah', order: 1),
        JobTemplate(id: 'j3', name: 'Cuci piring', order: 2),
        JobTemplate(id: 'j4', name: 'Buang sampah', order: 3),
      ]);

  @override
  Stream<List<JobAssignment>> watchAssignmentsForWeek(DateTime weekStart) =>
      Stream.value([
        JobAssignment(
            id: 'a1', jobTemplateId: 'j1', assignedProfileId: 'bunda', weekStart: weekStart),
        JobAssignment(
            id: 'a2', jobTemplateId: 'j2', assignedProfileId: 'aku', weekStart: weekStart),
        JobAssignment(
            id: 'a3', jobTemplateId: 'j3', assignedProfileId: 'adek', weekStart: weekStart),
      ]);

  @override
  Stream<List<Announcement>> watchAnnouncements() => Stream.value([
        Announcement(
          id: 'n1',
          authorProfileId: 'bunda',
          message: 'Ada tamu sore ini, tolong rumah dirapikan dulu ya',
          createdAt: now.subtract(const Duration(minutes: 25)),
        ),
        Announcement(
          id: 'n2',
          authorProfileId: 'adek',
          message: 'Token listrik habis',
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
      ]);

  @override
  Stream<List<ErrandItem>> watchErrandItems() => Stream.value([
        ErrandItem(
          id: 'i1',
          name: 'Susu UHT 1 liter',
          requestedByProfileId: 'bunda',
          createdAt: now,
        ),
        ErrandItem(
          id: 'i2',
          name: 'Beras 5 kg',
          requestedByProfileId: 'adek',
          createdAt: now,
        ),
        ErrandItem(
          id: 'i3',
          name: 'Sabun cuci piring',
          requestedByProfileId: 'aku',
          done: true,
          doneByProfileId: 'bunda',
          createdAt: now,
          doneAt: now,
        ),
      ]);

  @override
  Future<void> ensureSeedProfiles(Map<String, String> idToName, String adminId) async {}
}
