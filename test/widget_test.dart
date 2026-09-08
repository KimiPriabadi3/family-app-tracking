import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_app/screens/profile_select_screen.dart';

void main() {
  testWidgets('menampilkan baris kartu keluarga untuk Bunda, Mas, Adek',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileSelectScreen()));

    expect(find.text('Bunda'), findsOneWidget);
    expect(find.text('Mas'), findsOneWidget);
    expect(find.text('Adek'), findsOneWidget);
  });
}
