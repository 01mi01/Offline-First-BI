import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';

// Página de Business Intelligence: todavía no implementada, se muestra como
// un estado "próximamente".
class BusinessIntelligencePage extends StatelessWidget {
  const BusinessIntelligencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Business Intelligence', showBack: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insights_outlined,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Business Intelligence',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Próximamente',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
