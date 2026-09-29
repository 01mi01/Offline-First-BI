import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/business_intelligence_page.dart';
import '../pages/reports_page.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/landing_card.dart';
import 'nav_resolver.dart';
import '../widgets/profile_button.dart';

// Tab "Reportes + Business Intelligence" de la navegación inferior: pantalla
// de aterrizaje con tarjetas (Reportes, Business Intelligence), mostrando
// solo las que el usuario puede leer.
class ReportesBiTabPage extends ConsumerWidget {
  const ReportesBiTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveReportesCards(modules);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CustomAppBar(
            title: 'Reportes',
            actions: [ProfileButton()],
          ),
          body: cards.isEmpty
              ? Center(
                  child: Text(
                    'No tienes acceso a reportes ni business intelligence',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s12,
                            ),
                            child: LandingCard(
                              label: _labelFor(card),
                              icon: _iconFor(card),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _pageFor(card),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar Reportes')),
      ),
    );
  }
}

String _labelFor(ReportesCard card) {
  switch (card) {
    case ReportesCard.reportes:
      return 'Reportes';
    case ReportesCard.businessIntelligence:
      return 'Business Intelligence';
  }
}

IconData _iconFor(ReportesCard card) {
  switch (card) {
    case ReportesCard.reportes:
      return Icons.bar_chart_outlined;
    case ReportesCard.businessIntelligence:
      return Icons.insights_outlined;
  }
}

Widget _pageFor(ReportesCard card) {
  switch (card) {
    case ReportesCard.reportes:
      return const ReportsPage();
    case ReportesCard.businessIntelligence:
      return const BusinessIntelligencePage();
  }
}
