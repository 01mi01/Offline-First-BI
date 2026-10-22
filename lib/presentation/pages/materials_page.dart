import '../../config/quantity_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../config/rounding.dart';
import '../../application/product_provider.dart';
import '../../application/category_provider.dart';
import '../../application/record_search.dart';
import '../../application/status_filter.dart';
import '../../application/unit_provider.dart';
import '../../models/material_model.dart';
import '../../models/unit_model.dart';
import '../../models/product_material_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/screen_header.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/discard_guard.dart';
import '../widgets/live_validation.dart';
import '../widgets/single_flight.dart';
import '../widgets/unit_quantity_input.dart';
import '../widgets/flat_list.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../widgets/record_detail.dart';
import '../widgets/record_list.dart';
import '../widgets/status_badge.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_controls.dart';
import '../widgets/profile_button.dart';
import '../widgets/filter_panel.dart';
import '../../application/form_validation.dart';
import '../widgets/app_style.dart';
import '../widgets/empty_state.dart';
import '../widgets/picker_options.dart';

class MaterialsPage extends ConsumerWidget {
  const MaterialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: ScreenScaffold(
        title: 'Materiales',
        actions: const [ProfileButton()],
        bottom: const AppTabSwitcher(labels: ['Materiales', 'Registro de uso']),
        body: const TabBarView(
          children: [MaterialsListTab(), MaterialsUsageTab()],
        ),
      ),
    );
  }
}

class MaterialsListTab extends ConsumerWidget {
  const MaterialsListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(materialProvider);
    final units = ref.watch(unitProvider).units;
    final status = ref.watch(materialStatusFilterProvider);
    final query = ref.watch(materialListQueryProvider);
    final visible = ref
        .watch(materialSearchIndexProvider)
        .search(query)
        .where((m) => status.matches(m.isActive))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'materials_list_tab_fab',
        onPressed: () => _showDialog(context, null),
      ),
      body: Column(
        children: [
          FilterArea(
            search: AppSearchBar(
              initialText: query,
              hintText: 'Buscar material',
              onChanged: (value) =>
                  ref.read(materialListQueryProvider.notifier).state = value,
            ),
            fields: [
              FilterDropdown<StatusFilter>(
                label: 'Estado',
                options: statusFilterOptions(),
                current: status,
                defaultValue: StatusFilter.all,
                onApply: (value) =>
                    ref.read(materialStatusFilterProvider.notifier).state =
                        value,
              ),
            ],
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.materials.isEmpty
                ? Center(
                    child: AppEmptyState.list(
                      plural: 'materiales',
                      icon: Icons.palette_rounded,
                      actionLabel: 'Nuevo material',
                      onAction: () => _showDialog(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState.noMatch(),
                  )
                : AppGroupListView(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final m = visible[index];
                      final unit = units
                          .where((u) => u.id == m.unitId)
                          .firstOrNull;
                      return _MaterialRow(
                        material: m,
                        unitName: unit?.name,
                        unitType: unit?.type,
                        onEdit: () => _showDialog(context, m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, MaterialModel? material) {
    showFormSheet<void>(
      context,
      builder: (_) => MaterialDialog(material: material),
    );
  }
}

class MaterialsUsageTab extends ConsumerStatefulWidget {
  const MaterialsUsageTab({super.key});

  @override
  ConsumerState<MaterialsUsageTab> createState() => _MaterialsUsageTabState();
}

class _MaterialsUsageTabState extends ConsumerState<MaterialsUsageTab> {
  int? _selectedProductId;
  List<ProductMaterialModel> _usageLog = [];
  bool _loading = false;
  bool _searching = false;

  Future<void> _loadUsageLog(int productId) async {
    setState(() => _loading = true);
    final log = await ref
        .read(materialProvider.notifier)
        .getMaterialsForProduct(productId);
    if (mounted) {
      setState(() {
        _usageLog = log;
        _loading = false;
      });
    }
  }

  void _showRegisterSheet() {
    if (_selectedProductId == null) return;
    showFormSheet<void>(
      context,
      builder: (_) => _RegisterUsageSheet(
        productId: _selectedProductId!,
        onRegistered: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  void _showEditSheet(ProductMaterialModel entry) {
    showFormSheet<void>(
      context,
      builder: (_) => _EditUsageSheet(
        entry: entry,
        onEdited: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  void _showUsageDetail(ProductMaterialModel entry) {
    final quantity =
        quantityWithUnit(entry.quantityUsed, entry.materialUnitName);
    showAppSheet<void>(
      context,
      builder: (_) => RecordDetailSheet(
        title: 'Detalle del registro de uso',
        onEdit: entry.isCanceled ? null : () => _showEditSheet(entry),
        children: [
          RecordHeadline(
            title: entry.materialName,
            pill: entry.isCanceled
                ? const StatusBadge.canceled(label: 'Cancelado')
                : null,
            note: entry.isCanceled
                ? 'La cantidad ya volvió al stock del material.'
                : null,
          ),
          AppSection(
            children: [
              AppValueRow(label: 'Cantidad', value: quantity),
              AppValueRow(
                label: 'Precio por unidad',
                value:
                    'Bs. ${fixed2(entry.pricePerUnit)} / ${entry.materialUnitName}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref
        .watch(productProvider)
        .products
        .where((p) => p.isActive)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _selectedProductId != null && !_searching
          ? FlatFab(
              heroTag: 'materials_usage_tab_fab',
              onPressed: _showRegisterSheet,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            child: SearchablePickerField<int>(
              searchStyle: true,
              label: 'Producto',
              showLabel: false,
              searchHint: 'Producto',
              value: _selectedProductId,
              options: productPickerOptions(
                products,
                ref.watch(categoryProvider).categories,
              ),
              onFocusChanged: (focused) {
                if (focused != _searching) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _searching = focused);
                  });
                }
              },
              onChanged: (val) {
                setState(() {
                  _selectedProductId = val;
                  _usageLog = [];
                });
                if (val != null) _loadUsageLog(val);
              },
            ),
          ),

          if (_searching)
            const Spacer()
          else if (_selectedProductId == null)
            const Expanded(
              child: Center(
                child: AppEmptyState.hint(
                  icon: Icons.palette_rounded,
                  text:
                      'Selecciona un producto para ver el registro de uso de materiales.',
                ),
              ),
            )
          else if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_usageLog.isEmpty)
            Expanded(
              child: Center(
                child: AppEmptyState.list(
                  plural: 'usos de materiales',
                  icon: Icons.history_rounded,
                ),
              ),
            )
          else
            Expanded(
              child: AppGroupListView(
                itemCount: _usageLog.length,
                itemBuilder: (context, index) {
                  final entry = _usageLog[index];
                  return RecordRow(
                    title: entry.materialName,
                    titleColor: entry.isCanceled
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    details: [
                      RecordLine(
                        'Cantidad: ${quantityWithUnit(entry.quantityUsed, entry.materialUnitName)}',
                      ),
                      RecordLine(
                        'Bs. ${fixed2(entry.pricePerUnit)} / ${entry.materialUnitName}',
                      ),
                    ],
                    pill: entry.isCanceled
                        ? const StatusBadge.canceled(label: 'Cancelado')
                        : null,
                    onTap: () => _showUsageDetail(entry),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RegisterUsageSheet extends ConsumerStatefulWidget {
  final int productId;
  final VoidCallback onRegistered;

  const _RegisterUsageSheet({
    required this.productId,
    required this.onRegistered,
  });

  @override
  ConsumerState<_RegisterUsageSheet> createState() =>
      _RegisterUsageSheetState();
}

class _RegisterUsageSheetState extends ConsumerState<_RegisterUsageSheet>
    with SingleFlight<_RegisterUsageSheet>, LiveValidation<_RegisterUsageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  int? _selectedMaterialId;
  double _fractionQuantity = 0;
  String? _error;
  late final String _initialSignature;

  @override
  GlobalKey<FormState> get validationKey => _formKey;

  @override
  String valuesSnapshot() => _signature();

  @override
  void clearMessages() {_error = null;}

  MaterialModel? get _selectedMaterial => ref
      .read(materialProvider)
      .materials
      .where((m) => m.id == _selectedMaterialId)
      .firstOrNull;

  UnitModel? get _selectedUnit {
    final material = _selectedMaterial;
    if (material == null) return null;
    return ref
        .read(unitProvider)
        .units
        .where((u) => u.id == material.unitId)
        .firstOrNull;
  }

  String? get _materialError =>
      submitAttempted && _selectedMaterialId == null
          ? 'Selecciona un material'
          : null;

  String? get _quantityError {
    final material = _selectedMaterial;
    final unit = _selectedUnit;
    if (!submitAttempted ||
        material == null ||
        unit == null ||
        !isFractionFriendlyUnitType(unit.type)) {
      return null;
    }
    if (_fractionQuantity <= 0) return 'Selecciona una cantidad';
    if (_fractionQuantity > roundQuantity(material.stock, unitType: unit.type)) {
      return 'Cantidad máxima disponible: ${quantityWithUnit(material.stock, unit.name)}';
    }
    return null;
  }

  String _signature() => [
    _selectedMaterialId,
    _quantityController.text,
    _fractionQuantity,
  ].join('\u0000');

  @override
  void initState() {
    super.initState();
    _initialSignature = _signature();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final material = ref
        .read(materialProvider)
        .materials
        .where((m) => m.id == _selectedMaterialId)
        .firstOrNull;
    final unit = material != null
        ? ref
              .read(unitProvider)
              .units
              .where((u) => u.id == material.unitId)
              .firstOrNull
        : null;
    final usesFractions = unit != null && isFractionFriendlyUnitType(unit.type);

    markAttempted();
    if (_materialError != null) return;
    if (!usesFractions && !validateForm()) return;

    final quantity = roundQuantity(
      usesFractions
          ? _fractionQuantity
          : double.tryParse(_quantityController.text.trim()) ?? 0,
      unitType: unit?.type ?? 'medida',
    );

    if (quantity <= 0 || _quantityError != null) return;

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .registerUsage(
          productId: widget.productId,
          materialId: _selectedMaterialId!,
          quantityUsed: quantity,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.pop(context);
    widget.onRegistered();
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _signature() != _initialSignature,
      onValuesChanged: syncValues,
      changes: Listenable.merge([
        _quantityController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final materials = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.isActive && m.stock > 0)
        .toList();
    final units = ref.watch(unitProvider).units;
    final selectedMaterial = _selectedMaterialId != null
        ? materials.where((m) => m.id == _selectedMaterialId).firstOrNull
        : null;
    final selectedUnit = selectedMaterial != null
        ? units.where((u) => u.id == selectedMaterial.unitId).firstOrNull
        : null;
    final availableText = selectedMaterial == null
        ? ''
        : quantityWithUnit(selectedMaterial.stock, selectedUnit?.name);

    return FormSheet(
      title: 'Registrar uso de material',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: 'Registrar',
        onPrimary: () => runOnce(_register),
        busy: inFlight,
      ),
      children: [
        SearchablePickerField<int>(
          label: 'Material',
          searchHint: 'Buscar material',
          value: _selectedMaterialId,
          options: materialPickerOptions(
            materials,
            ref.watch(unitProvider).units,
          ),
          onChanged: (val) => setState(() => _selectedMaterialId = val),
        ),
        if (_materialError != null) FormErrorText(_materialError!),
        if (selectedMaterial != null) ...[
          const SizedBox(height: AppSpacing.s6),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s4),
            child: Text(
              'Stock disponible: $availableText',
              style: AppText.footnote(context),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),

        if (selectedUnit != null && isFractionFriendlyUnitType(selectedUnit.type))
          FractionQuantityPicker(
            unit: selectedUnit.name,
            value: _fractionQuantity,
            onChanged: (v) => setState(() => _fractionQuantity = v),
            label: 'Cantidad utilizada',
          )
        else if (selectedUnit != null &&
            isDiscreteUnit(selectedUnit.type, selectedUnit.name))
          WholeNumberQuantityField(
            controller: _quantityController,
            labelText: 'Cantidad utilizada (${selectedUnit.name})',
            extraValidator: (qty) => selectedMaterial != null &&
                    qty > selectedMaterial.stock
                ? 'Cantidad máxima disponible: $availableText'
                : null,
          )
        else
          LabeledField(
            label: selectedUnit != null
                ? 'Cantidad utilizada (${selectedUnit.name})'
                : 'Cantidad utilizada',
            builder: (_) => TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
              validator: (v) {
                final error = validateDecimal(
                  v,
                  maxDecimals: 2,
                  max: maxQuantity,
                );
                if (error != null) return error;
                if (selectedMaterial != null &&
                    parseNumber(v)! >
                        roundQuantity(
                          selectedMaterial.stock,
                          unitType: selectedUnit?.type ?? 'medida',
                        )) {
                  return 'Cantidad máxima disponible: $availableText';
                }
                return null;
              },
            ),
          ),
        if (_quantityError != null) FormErrorText(_quantityError!),

        if (_error != null) FormErrorText(_error!),
      ],
    );
  }
}

class _EditUsageSheet extends ConsumerStatefulWidget {
  final ProductMaterialModel entry;
  final VoidCallback onEdited;

  const _EditUsageSheet({required this.entry, required this.onEdited});

  @override
  ConsumerState<_EditUsageSheet> createState() => _EditUsageSheetState();
}

class _EditUsageSheetState extends ConsumerState<_EditUsageSheet>
    with SingleFlight<_EditUsageSheet>, LiveValidation<_EditUsageSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late double _fractionQuantity;
  String? _error;
  late final String _initialSignature;

  @override
  GlobalKey<FormState> get validationKey => _formKey;

  @override
  String valuesSnapshot() => _signature();

  @override
  void clearMessages() {_error = null;}

  String? get _quantityError {
    if (!submitAttempted || !_usesFractions) return null;
    if (_fractionQuantity <= 0) return 'Selecciona una cantidad';
    final available = _availableQuantity;
    if (_fractionQuantity > available) {
      return 'Máximo disponible: ${quantityWithUnit(available, widget.entry.materialUnitName)}';
    }
    return null;
  }

  double get _availableQuantity => roundQuantity(
    (ref
                .read(materialProvider)
                .materials
                .where((m) => m.id == widget.entry.materialId)
                .firstOrNull
                ?.stock ??
            0) +
        widget.entry.quantityUsed,
    unitType: widget.entry.materialUnitType,
  );

  String _signature() => [
    _quantityController.text,
    _fractionQuantity,
  ].join('\u0000');

  bool get _usesFractions =>
      isFractionFriendlyUnitType(widget.entry.materialUnitType);

  bool get _isDiscrete => isDiscreteUnit(
    widget.entry.materialUnitType,
    widget.entry.materialUnitName,
  );

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: formatQuantity(widget.entry.quantityUsed),
    );
    _fractionQuantity = widget.entry.quantityUsed;
    _initialSignature = _signature();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _cancelUsage() async {
    final entry = widget.entry;
    final confirmed = await confirmCancellation(
      context,
      title: 'Cancelar el registro de uso',
      message:
          '${round2(entry.quantityUsed) == 1 ? 'Se devolverá' : 'Se devolverán'} '
          '${quantityWithUnit(entry.quantityUsed, entry.materialUnitName)} de '
          '"${entry.materialName}" al stock.',
      confirmLabel: 'Cancelar el registro de uso',
    );
    if (!confirmed || !mounted) return;
    final error = await ref.read(materialProvider.notifier).cancelUsage(entry.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.onEdited();
    Navigator.pop(context);
  }

  Future<void> _save() async {
    markAttempted();
    if (!_usesFractions && !validateForm()) return;
    if (_quantityError != null) return;

    final newQuantity = _usesFractions
        ? _fractionQuantity
        : double.tryParse(_quantityController.text.trim()) ?? 0;

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .editUsage(recordId: widget.entry.id, newQuantity: newQuantity);

    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.pop(context);
    widget.onEdited();
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _signature() != _initialSignature,
      onValuesChanged: syncValues,
      changes: Listenable.merge([
        _quantityController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final material = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.id == widget.entry.materialId)
        .firstOrNull;

    final availableStock = roundQuantity(
      (material?.stock ?? 0) + widget.entry.quantityUsed,
      unitType: widget.entry.materialUnitType,
    );
    final availableText = quantityWithUnit(
      availableStock,
      widget.entry.materialUnitName,
    );

    return FormSheet(
      title: 'Editar registro de uso',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: 'Guardar',
        onPrimary: () => runOnce(_save),
        busy: inFlight,
        destructive: AppActionButton(
          label: 'Cancelar el registro de uso',
          kind: AppButtonKind.destructive,
          onPressed: inFlight ? null : () => runOnce(_cancelUsage),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: Text(
            widget.entry.materialName,
            style: AppText.rowSubtitle(context),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        if (_usesFractions) ...[
          FractionQuantityPicker(
            unit: widget.entry.materialUnitName,
            value: _fractionQuantity,
            onChanged: (v) {
              setState(() {
                _fractionQuantity = v;
                _error = null;
              });
            },
            label: 'Nueva cantidad',
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            'Máximo disponible: $availableText',
            style: AppText.footnote(context),
          ),
        ] else if (_isDiscrete)
          WholeNumberQuantityField(
            controller: _quantityController,
            labelText: 'Nueva cantidad (${widget.entry.materialUnitName})',
            helperText:
                'Máximo disponible: $availableText',
            extraValidator: (qty) =>
                qty > availableStock ? 'Máximo: $availableText' : null,
          )
        else
          LabeledField(
            label: 'Nueva cantidad (${widget.entry.materialUnitName})',
            builder: (_) => TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0',
                helperText:
                    'Máximo disponible: $availableText',
              ),
              validator: (v) {
                final error = validateDecimal(
                  v,
                  maxDecimals: 2,
                  max: maxQuantity,
                );
                if (error != null) return error;
                if (parseNumber(v)! > availableStock) {
                  return 'Máximo: $availableText';
                }
                return null;
              },
            ),
          ),

        if (_error != null) FormErrorText(_error!),

      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  final MaterialModel material;
  final String? unitName;
  final String? unitType;
  final VoidCallback onEdit;

  const _MaterialRow({
    required this.material,
    required this.unitName,
    required this.unitType,
    required this.onEdit,
  });

  String get _stockText =>
      quantityWithUnit(material.stock, unitName);

  String get _priceText =>
      'Bs. ${fixed2(material.pricePerUnit)}${unitName != null ? ' / $unitName' : ''}';

  void _showDetail(BuildContext context) {
    final description = material.description;
    showAppSheet<void>(
      context,
      builder: (_) => RecordDetailSheet(
        title: 'Detalle del material',
        onEdit: onEdit,
        children: [
          RecordHeadline(
            title: material.name,
            pill: StatusBadge.forState(isActive: material.isActive),
          ),
          AppSection(
            children: [
              if (description != null && description.isNotEmpty)
                AppValueRow(label: 'Descripción', value: description),
              if (unitName != null)
                AppValueRow(label: 'Unidad', value: unitName!),
              AppValueRow(label: 'Precio por unidad', value: _priceText),
              AppValueRow(label: 'Stock', value: _stockText),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = material.description;
    return RecordRow(
      onTap: () => _showDetail(context),
      title: material.name,
      details: [
        if (description != null && description.isNotEmpty)
          RecordLine(description, maxLines: 2),
        RecordLine(_priceText),
        RecordLine('Stock: $_stockText'),
      ],
      pill: StatusBadge.forState(isActive: material.isActive),
    );
  }
}

