import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/pages/report_detail_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('the export menu shows an Excel icon and a PDF icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: const ReportDetailPage(
            title: 'Ventas',
            type: ReportType.sales,
            saleRows: [],
            purchases: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elegir formato'));
    await tester.pumpAndSettle();

    expect(find.text('Exportar Excel'), findsOneWidget);
    expect(find.text('Exportar PDF'), findsOneWidget);

    final excel = tester.widget<Icon>(find.byIcon(Icons.table_chart_rounded));
    final pdf = tester.widget<Icon>(find.byIcon(Icons.picture_as_pdf_rounded));
    expect(excel.color, AppColors.success);
    expect(pdf.color, AppColors.error);
  });
}
