import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/profile_select_screen.dart';
import 'services/background_poll.dart';
import 'services/geofence_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.init();
  await GeofenceService.instance.init();
  await Workmanager().initialize(notificationCallbackDispatcher);
  await NotificationService.instance.consumeLaunchPayload();
  runApp(const FamilyApp());
}

class FamilyApp extends StatelessWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family App Tracking',
      // Ships as a debug build, and the corner ribbon has no business on a
      // phone the family actually uses.
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      home: const SessionGate(),
    );
  }
}
