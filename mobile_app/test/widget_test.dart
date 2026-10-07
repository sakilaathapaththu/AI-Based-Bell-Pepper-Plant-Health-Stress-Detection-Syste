import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bell_pepper_app/app.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';

void main() {
  testWidgets('Splash screen shows app branding, then onboarding after 3s',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PepperCareApp());

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);
    expect(find.text(AppStrings.splashCaption), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text(AppStrings.appName), findsNothing);
    expect(find.text(AppStrings.getStarted), findsOneWidget);
  });
}
