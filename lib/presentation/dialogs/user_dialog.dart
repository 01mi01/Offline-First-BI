import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../application/form_validation.dart';
import '../../application/user_provider.dart';
import '../../application/user_validation.dart';
import '../../models/app_role.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/discard_guard.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../widgets/live_validation.dart';
import '../widgets/single_flight.dart';

class PasswordVisibilityButton extends StatelessWidget {
  final bool obscured;
  final VoidCallback onPressed;

  const PasswordVisibilityButton({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.textMuted,
      ),
      onPressed: onPressed,
    );
  }
}

class UserDialog extends ConsumerStatefulWidget {
  final UserModel? user;

  const UserDialog({super.key, this.user});

  @override
  ConsumerState<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<UserDialog>
    with SingleFlight<UserDialog>, LiveValidation<UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  AppRole? _role;
  bool _obscurePassword = true;
  String? _saveError;
  late final String _initialSignature;

  bool get _isEditing => widget.user != null;

  bool get _isSelf =>
      _isEditing && ref.read(authProvider).user?.id == widget.user!.id;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.user?.username ?? '',
    );
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _role = widget.user?.appRole;
    _initialSignature = _signature();
  }

  @override
  GlobalKey<FormState> get validationKey => _formKey;

  @override
  String valuesSnapshot() => _signature();

  @override
  void clearMessages() {
    _saveError = null;
  }

  String _signature() => [
    _usernameController.text,
    _emailController.text,
    _passwordController.text,
    _role?.name ?? '',
  ].join('\u0000');

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Iterable<UserModel> get _others => ref
      .read(userManagementProvider)
      .users
      .where((u) => u.id != widget.user?.id);

  String? _validateUsername(String? value) {
    final error = validateUsername(value);
    if (error != null) return error;
    final name = value!.trim().toLowerCase();
    if (_others.any((u) => u.username.toLowerCase() == name)) {
      return 'Ya existe un usuario con ese nombre';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final error = validateEmail(value);
    if (error != null) return error;
    final email = value!.trim().toLowerCase();
    if (_others.any((u) => u.email.toLowerCase() == email)) {
      return 'Ya existe un usuario con ese correo';
    }
    return null;
  }

  Future<void> _save() async {
    if (!validateForm()) return;
    setState(() => _saveError = null);
    final notifier = ref.read(userManagementProvider.notifier);
    final error = _isEditing
        ? await notifier.update(
            id: widget.user!.id,
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            role: _role!,
          )
        : await notifier.create(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _role!,
          );
    if (!mounted) return;
    if (error != null) {
      setState(() => _saveError = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _signature() != _initialSignature,
      onValuesChanged: syncValues,
      changes: Listenable.merge([
        _usernameController,
        _emailController,
        _passwordController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final roleLocked = _isSelf;
    return FormSheet(
      title: _isEditing ? 'Editar usuario' : 'Nuevo usuario',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: _isEditing ? 'Guardar' : 'Crear',
        onPrimary: () => runOnce(_save),
        busy: inFlight,
      ),
      children: [
        LabeledField(
          label: 'Nombre de usuario',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _usernameController,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'Nombre para iniciar sesión',
            ),
            validator: _validateUsername,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        LabeledField(
          label: 'Correo',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _emailController,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'correo@ejemplo.com',
            ),
            validator: _validateEmail,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppDropdownField<AppRole>(
          label: 'Rol',
          value: _role,
          hint: 'Elige un rol',
          helperText: roleLocked ? 'No puedes cambiar tu propio rol' : null,
          options: [
            for (final role in AppRole.values)
              DropdownOption(role, role.label),
          ],
          onChanged: roleLocked
              ? null
              : (value) => setState(() {
                  _role = value;
                  _saveError = null;
                }),
          validator: (value) => value == null ? requiredMessage : null,
        ),
        if (!_isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          LabeledField(
            label: 'Contraseña',
            builder: (_) => TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'Mínimo $minPasswordLength caracteres',
                suffixIcon: PasswordVisibilityButton(
                  obscured: _obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: validatePassword,
            ),
          ),
        ],
        if (_saveError != null) FormErrorText(_saveError!),
      ],
    );
  }
}

class ResetPasswordDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const ResetPasswordDialog({super.key, required this.user});

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog>
    with SingleFlight<ResetPasswordDialog>, LiveValidation<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _saveError;

  @override
  GlobalKey<FormState> get validationKey => _formKey;

  @override
  String valuesSnapshot() => _passwordController.text;

  @override
  void clearMessages() {
    _saveError = null;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!validateForm()) return;
    setState(() => _saveError = null);
    final error = await ref
        .read(userManagementProvider.notifier)
        .resetPassword(widget.user.id, _passwordController.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saveError = error);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Contraseña de ${widget.user.username} restablecida'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _passwordController.text.isNotEmpty,
      onValuesChanged: syncValues,
      changes: _passwordController,
      child: FormSheet(
        title: 'Restablecer contraseña',
        formKey: _formKey,
        actions: FormActions(
          onSecondary: () => Navigator.pop(context),
          primaryLabel: 'Guardar',
          onPrimary: () => runOnce(_save),
          busy: inFlight,
        ),
        children: [
          LabeledField(
            label: 'Nueva contraseña para ${widget.user.username}',
            builder: (_) => TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'Mínimo $minPasswordLength caracteres',
                suffixIcon: PasswordVisibilityButton(
                  obscured: _obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: validatePassword,
            ),
          ),
          if (_saveError != null) FormErrorText(_saveError!),
        ],
      ),
    );
  }
}
