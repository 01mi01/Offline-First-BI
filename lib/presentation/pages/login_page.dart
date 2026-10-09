import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../application/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../navigation/main_navigation_page.dart';

const double _maxContentWidth = 420;
const double _cardRadius = AppSpacing.s28;
const Duration _motion = Duration(milliseconds: 300);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authProvider.notifier)
        .login(_usernameController.text.trim(), _passwordController.text);

    final state = ref.read(authProvider);
    if (state.user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppIos.groupRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    final enabled = border(AppColors.border);
    final focused = border(AppColors.primaryDark, 2);
    return InputDecoration(
      hintText: hint,
      fillColor: AppColors.surface,
      prefixIcon: Icon(icon),
      prefixIconColor: AppColors.primaryDark,
      suffixIcon: suffix,
      border: enabled,
      enabledBorder: enabled,
      errorBorder: enabled,
      focusedBorder: focused,
      focusedErrorBorder: focused,
      errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const padding = AppSpacing.s24;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(padding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 2 * padding).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: _EntranceFade(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s24,
                          vertical: AppSpacing.s48,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.all(
                            Radius.circular(_cardRadius),
                          ),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: SvgPicture.asset(
                                'assets/images/logo.svg',
                                width: MediaQuery.of(context).size.width * 0.6,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s32),
                            Text(
                              'Iniciar sesión',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondaryDark,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.s32),
                            _buildForm(context, authState),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AuthState authState) {
    final fieldStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: AppColors.textPrimary,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _usernameController,
            style: fieldStyle,
            cursorColor: AppColors.primaryDark,
            cursorErrorColor: AppColors.primaryDark,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              hint: 'Nombre de usuario',
              icon: Icons.person_outline,
            ),
            validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
          ),
          const SizedBox(height: AppSpacing.s20),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: fieldStyle,
            cursorColor: AppColors.primaryDark,
            cursorErrorColor: AppColors.primaryDark,
            textInputAction: TextInputAction.done,
            decoration: _decoration(
              hint: 'Tu contraseña',
              icon: Icons.lock_outline,
              suffix: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s4),
                child: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.primaryDark,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
          ),
          const SizedBox(height: AppSpacing.s32),
          AnimatedSize(
            duration: _motion,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: _motion,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: authState.error == null
                  ? const SizedBox(width: double.infinity)
                  : _ErrorText(
                      key: ValueKey(authState.error),
                      message: authState.error!,
                    ),
            ),
          ),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.textButtons,
              disabledBackgroundColor: AppColors.primaryDark,
              disabledForegroundColor: AppColors.textButtons,
            ),
            child: authState.isLoading
                ? const SizedBox(
                    height: AppSpacing.s20,
                    width: AppSpacing.s20,
                    child: CircularProgressIndicator(
                      color: AppColors.textButtons,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Iniciar sesión',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textButtons,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

class _EntranceFade extends StatelessWidget {
  final Widget child;

  const _EntranceFade({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _motion,
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * AppSpacing.s16),
          child: child,
        ),
      ),
    );
  }
}
