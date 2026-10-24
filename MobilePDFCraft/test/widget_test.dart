import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pdfcraft/main.dart';

void main() {
  testWidgets('MobilePdfCraftApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MobilePdfCraftApp());
    await tester.pumpAndSettle();

    // Verify Facebook-style branding
    expect(find.text('pdfcraft'), findsOneWidget);

    // Verify presence of creation composer
    expect(find.text('What PDF would you like to craft today?'), findsOneWidget);
  });
}
