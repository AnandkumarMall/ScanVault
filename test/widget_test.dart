// Smoke test for the onboarding screen — the Vault-connect entry point.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scanvault/src/features/onboarding/connect_screen.dart';

void main() {
  testWidgets('ConnectScreen shows the welcome + folder-picker CTA',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ConnectScreen()),
      ),
    );

    expect(find.text('Choose Vault folder'), findsOneWidget);
    expect(find.textContaining('Welcome to'), findsOneWidget);
  });
}
