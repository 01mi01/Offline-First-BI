import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../config/rounding.dart';
import '../../application/product_provider.dart';
import '../../application/search_filter.dart';
import '../../application/status_filter.dart';
import '../../application/unit_provider.dart';
import '../../models/material_model.dart';
import '../../models/product_material_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/screen_header.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/confirm_cancel_dialog.dart';
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

// Página de Materiales: lista de materiales y registro de uso por producto,
// como dos tabs internos. Se llega aquí desde la tarjeta "Materiales" del
// tab "Inventario" de la navegación inferior.
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

// Tab de lista de materiales, sin AppBar propia (la aporta MaterialsPage).
class MaterialsListTab extends ConsumerWidget {
  const MaterialsListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(materialProvider);
    final units = ref.watch(unitProvider).units;
    final status = ref.watch(materialStatusFilterProvider);
    final query = ref.watch(materialListQueryProvider);
    // Búsqueda por nombre (sin distinguir tildes) y filtro por estado.
    final visible = filterByQuery<MaterialModel>(
      state.materials.where((m) => status.matches(m.isActive)),
      query,
      (m) => m.name,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
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
                    child: AppEmptyState(
                      icon: Icons.palette_rounded,
                      title: 'No se registraron materiales',
                      actionLabel: 'Nuevo material',
                      onAction: () => _showDialog(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sin resultados',
                    ),
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
    showAppSheet<void>(
      context,
      builder: (_) => MaterialDialog(material: material),
    );
  }
}

// Tab de registro de uso de materiales por producto. Se usa como sub-tab
// dentro del tab "Inventario" de la navegación inferior; no tiene AppBar propia.
class MaterialsUsageTab extends ConsumerStatefulWidget {
  const MaterialsUsageTab({super.key});

  @override
  ConsumerState<MaterialsUsageTab> createState() => _MaterialsUsageTabState();
}

class _MaterialsUsageTabState extends ConsumerState<MaterialsUsageTab> {
  int? _selectedProductId;
  List<ProductMaterialModel> _usageLog = [];
  bool _loading = false;

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
    showAppSheet<void>(
      context,
      builder: (_) => _RegisterUsageSheet(
        productId: _selectedProductId!,
        onRegistered: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  void _showEditSheet(ProductMaterialModel entry) {
    showAppSheet<void>(
      context,
      builder: (_) => _EditUsageSheet(
        entry: entry,
        onEdited: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  // Detalle de un registro de uso. Uno cancelado es solo historial: sin
  // "Editar".
  void _showUsageDetail(ProductMaterialModel entry) {
    final quantity =
        '${_qty(entry.quantityUsed, entry.materialUnitType, entry.materialUnitName)} ${unitLabel(entry.materialUnitName, entry.quantityUsed)}';
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
                    'Bs. ${fixed2(entry.pricePerUnit)} / ${entry.materialUnitName}',
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
      floatingActionButton: _selectedProductId != null
          ? FlatFab(
              // Tag único: evita colisiones de Hero cuando varias pestañas
              // con FAB conviven montadas a la vez bajo el shell de
              // navegación inferior.
              heroTag: 'materials_usage_tab_fab',
              onPressed: _showRegisterSheet,
            )
          : null,
      body: Column(
        children: [
          // Selector de producto: búsqueda por nombre, sin lista hasta escribir.
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
              options: [
                for (final p in products) PickerOption<int>(p.id, p.name),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedProductId = val;
                  _usageLog = [];
                });
                if (val != null) _loadUsageLog(val);
              },
            ),
          ),

          if (_selectedProductId == null)
            const Expanded(
              child: Center(
                child: AppEmptyState(
                  icon: Icons.palette_rounded,
                  title: 'Selecciona un producto',
                  message: 'para ver el registro de uso de materiales',
                ),
              ),
            )
          else if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_usageLog.isEmpty)
            const Expanded(
              child: Center(
                child: AppEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Sin registros de uso',
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
                        'Cantidad: ${_qty(entry.quantityUsed, entry.materialUnitType, entry.materialUnitName)} ${unitLabel(entry.materialUnitName, entry.quantityUsed)}',
                      ),
                      RecordLine(
                        'Bs. ${fixed2(entry.pricePerUnit)} / ${entry.materialUnitName}',
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

// Hoja para registrar nuevo uso de material
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

class _RegisterUsageSheetState extends ConsumerState<_RegisterUsageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  int? _selectedMaterialId;
  double _fractionQuantity = 0;
  // Errores del formulario: del material, de la cantidad elegida con las
  // fracciones y los del registro (p. ej. stock insuficiente).
  String? _materialError;
  String? _quantityError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_clearError);
  }

  // Un aviso de error desaparece en cuanto la persona cambia la cantidad o el
  // material.
  void _clearError() {
    if (_error != null || _quantityError != null) {
      setState(() {
        _error = null;
        _quantityError = null;
      });
    }
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

    if (_selectedMaterialId == null) {
      setState(() => _materialError = 'Selecciona un material');
      return;
    }
    if (!usesFractions && !_formKey.currentState!.validate()) return;

    // Lo escrito con más decimales de los permitidos se redondea (dos en
    // medidas; fracciones sin ruido).
    final quantity = roundQuantity(
      usesFractions
          ? _fractionQuantity
          : double.tryParse(_quantityController.text.trim()) ?? 0,
      unitType: unit?.type ?? 'medida',
    );

    if (quantity <= 0) {
      setState(() => _quantityError = 'Selecciona una cantidad');
      return;
    }
    // Se compara el stock ya redondeado: el ruido no bloquea ni deja pasar.
    if (material != null &&
        quantity >
            roundQuantity(material.stock, unitType: unit?.type ?? 'medida')) {
      setState(
        () => _quantityError =
            'Cantidad máxima disponible: ${_qty(material.stock, unit?.type, unit?.name)}',
      );
      return;
    }

    setState(() {
      _error = null;
      _quantityError = null;
    });

    final error = await ref
        .read(materialProvider.notifier)
        .registerUsage(
          productId: widget.productId,
          materialId: _selectedMaterialId!,
          quantityUsed: quantity,
        );

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo materiales activos con stock mayor a 0
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
        : _qty(selectedMaterial.stock, selectedUnit?.type, selectedUnit?.name);

    return FormSheet(
      title: 'Registrar uso de material',
      formKey: _formKey,
      children: [
        // Selector de material: buscar y elegir por nombre, igual que el
        // producto; escala con la cantidad de materiales y no lista nada hasta
        // escribir.
        SearchablePickerField<int>(
          label: 'Material',
          searchHint: 'Buscar material',
          value: _selectedMaterialId,
          options: [
            for (final m in materials) PickerOption<int>(m.id, m.name),
          ],
          onChanged: (val) => setState(() {
            _selectedMaterialId = val;
            _materialError = null;
            _quantityError = null;
            _error = null;
          }),
        ),
        if (_materialError != null) FormErrorText(_materialError!),
        // Muestra el stock disponible del material seleccionado
        if (selectedMaterial != null) ...[
          const SizedBox(height: AppSpacing.s6),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s4),
            child: Text(
              'Stock disponible: $availableText${selectedUnit != null ? ' ${unitLabel(selectedUnit.name, selectedMaterial.stock)}' : ''}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),

        // Cantidad: para unidades tipo envase (contenedor, paquete, rollo, tira)
        // se ofrecen fracciones simples en vez de pedir un decimal exacto; para
        // unidades "por pieza" (unidad genérica) se exige un entero.
        if (selectedUnit != null && isFractionFriendlyUnitType(selectedUnit.type))
          FractionQuantityPicker(
            unit: selectedUnit.name,
            value: _fractionQuantity,
            onChanged: (v) => setState(() {
              _fractionQuantity = v;
              _quantityError = null;
              _error = null;
            }),
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

        // Error del registro
        if (_error != null) FormErrorText(_error!),
        const SizedBox(height: AppSpacing.s24),

        // Botones cancelar y registrar
        FormActions(
          onSecondary: () => Navigator.pop(context),
          primaryLabel: 'Registrar',
          onPrimary: _register,
        ),
      ],
    );
  }
}

// Hoja para editar cantidad de un registro de uso existente
class _EditUsageSheet extends ConsumerStatefulWidget {
  final ProductMaterialModel entry;
  final VoidCallback onEdited;

  const _EditUsageSheet({required this.entry, required this.onEdited});

  @override
  ConsumerState<_EditUsageSheet> createState() => _EditUsageSheetState();
}

class _EditUsageSheetState extends ConsumerState<_EditUsageSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late double _fractionQuantity;
  String? _error;

  bool get _usesFractions =>
      isFractionFriendlyUnitType(widget.entry.materialUnitType);

  bool get _isDiscrete => isDiscreteUnit(
    widget.entry.materialUnitType,
    widget.entry.materialUnitName,
  );

  @override
  void initState() {
    super.initState();
    // Precarga la cantidad actual formateada
    _quantityController = TextEditingController(
      text: _qty(
        widget.entry.quantityUsed,
        widget.entry.materialUnitType,
        widget.entry.materialUnitName,
      ),
    );
    _fractionQuantity = widget.entry.quantityUsed;
    _quantityController.addListener(_clearError);
  }

  // Un aviso de error (p. ej. "Selecciona una cantidad") desaparece en cuanto
  // la persona cambia la cantidad o el material.
  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Cancela el registro de uso (no lo borra): devuelve la cantidad al stock
  // del material y deja el registro en el historial marcado como cancelado.
  // Solo se ofrece dentro de este formulario de edición.
  Future<void> _cancelUsage() async {
    final entry = widget.entry;
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cancelar registro de uso?',
      message:
          'Se devolverá ${_qty(entry.quantityUsed, entry.materialUnitType, entry.materialUnitName)} '
          '${unitLabel(entry.materialUnitName, entry.quantityUsed)} de '
          '"${entry.materialName}" al stock.',
      confirmLabel: 'Cancelar registro',
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
    if (!_usesFractions && !_formKey.currentState!.validate()) return;

    final newQuantity = _usesFractions
        ? _fractionQuantity
        : double.tryParse(_quantityController.text.trim()) ?? 0;

    if (_usesFractions && newQuantity <= 0) {
      setState(() => _error = 'Selecciona una cantidad');
      return;
    }
    // Se compara el stock ya redondeado, como al registrar.
    final available = roundQuantity(
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
    if (_usesFractions && newQuantity > available) {
      setState(
        () => _error =
            'Máximo disponible: ${_qty(available, widget.entry.materialUnitType, widget.entry.materialUnitName)}',
      );
      return;
    }

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .editUsage(recordId: widget.entry.id, newQuantity: newQuantity);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onEdited();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula stock disponible para validación
    final material = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.id == widget.entry.materialId)
        .firstOrNull;

    // Stock disponible = stock actual + cantidad original del registro
    final availableStock = roundQuantity(
      (material?.stock ?? 0) + widget.entry.quantityUsed,
      unitType: widget.entry.materialUnitType,
    );
    final availableText = _qty(
      availableStock,
      widget.entry.materialUnitType,
      widget.entry.materialUnitName,
    );

    return FormSheet(
      title: 'Editar registro de uso',
      formKey: _formKey,
      children: [
        // Muestra el material que se está editando
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: Text(
            widget.entry.materialName,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Campo de cantidad: fracciones simples para unidades tipo envase,
        // número decimal para el resto.
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
            'Máximo disponible: $availableText ${unitLabel(widget.entry.materialUnitName, availableStock)}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ] else if (_isDiscrete)
          WholeNumberQuantityField(
            controller: _quantityController,
            labelText: 'Nueva cantidad (${widget.entry.materialUnitName})',
            helperText:
                'Máximo disponible: $availableText ${unitLabel(widget.entry.materialUnitName, availableStock)}',
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
                    'Máximo disponible: $availableText ${unitLabel(widget.entry.materialUnitName, availableStock)}',
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

        // Error del registro
        if (_error != null) FormErrorText(_error!),
        const SizedBox(height: AppSpacing.s24),

        // Botones cancelar y guardar
        FormActions(
          onSecondary: () => Navigator.pop(context),
          primaryLabel: 'Guardar',
          onPrimary: _save,
        ),

        // Cancelar el registro: solo aquí, al final del formulario.
        const SizedBox(height: AppSpacing.s12),
        AppActionButton(
          label: 'Cancelar registro',
          kind: AppButtonKind.destructive,
          onPressed: _cancelUsage,
        ),
      ],
    );
  }
}

// Fila de material en la lista: nombre, descripción y precio por unidad a la
// izquierda; el stock, el dato clave, a la derecha.
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
      '${_qty(material.stock, unitType, unitName)}${unitName != null ? ' ${unitLabel(unitName!, material.stock)}' : ''}';

  String get _priceText =>
      'Bs. ${fixed2(material.pricePerUnit)}${unitName != null ? ' / $unitName' : ''}';

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

// Cantidad de un material según su unidad: dos decimales en medidas, fracciones
// exactas en unidades por fracciones y enteros en piezas (ver formatQuantity).
String _qty(double value, String? unitType, String? unitName) => formatMaterialQuantity(
  value,
  unitType: unitType ?? 'medida',
  unitName: unitName ?? '',
);
