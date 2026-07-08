import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:p4u_vendor_app/src/app.dart';

void main() {
  testWidgets('vendor app renders MaterialApp', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VendorApp()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
