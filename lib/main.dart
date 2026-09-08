import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/profile_select_screen.dart';
import 'services/notification_service.dart';
import 'theme/register_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.init();
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
      theme: buildRegisterTheme(brightness: Brightness.light),
      darkTheme: buildRegisterTheme(brightness: Brightness.dark),
      home: const SessionGate(),
    );
  }
}
