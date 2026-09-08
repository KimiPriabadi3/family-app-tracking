import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/profile_select_screen.dart';
import 'services/notification_service.dart';

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
      title: 'Family App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const SessionGate(),
    );
  }
}
