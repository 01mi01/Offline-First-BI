import 'package:flutter/material.dart';
import '../../data/services/totp.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_style.dart';

const String twoFactorSetupTitle = 'Clave de configuración';
const String twoFactorSetupSteps =
    'En Google Authenticator: tocar «+», elegir «Ingresar una clave de '
    'configuración», escribir el nombre de la cuenta y esta clave, y dejar '
    'el tipo «Basada en el tiempo».';
const String twoFactorSetupNote =
    'La clave no vuelve a mostrarse. Para cambiarla, desactivar y volver a '
    'activar la verificación en dos pasos.';

class TwoFactorSetupSheet extends StatelessWidget {
  final String username;
  final String secret;

  const TwoFactorSetupSheet({
    super.key,
    required this.username,
    required this.secret,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: twoFactorSetupTitle,
      expand: false,
      actions: AppActionButton(
        label: 'Listo',
        kind: AppButtonKind.primary,
        onPressed: () => Navigator.pop(context),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(
          top: AppSpacing.s8,
          bottom: AppSpacing.s16,
        ),
        children: [
          AppSection(
            header: 'Google Authenticator',
            children: [
              AppValueRow(label: 'Cuenta', value: username),
              const AppValueRow(
                label: 'Tipo de clave',
                value: 'Basada en el tiempo',
              ),
            ],
          ),
          AppSection(
            header: 'Clave',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: SelectableText(
                  formatSetupKey(secret),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            child: Text(twoFactorSetupSteps, style: AppText.footnote(context)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Text(twoFactorSetupNote, style: AppText.footnote(context)),
          ),
        ],
      ),
    );
  }
}
