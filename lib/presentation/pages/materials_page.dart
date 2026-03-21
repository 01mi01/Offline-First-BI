import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../application/product_provider.dart';
import '../../models/material_model.dart';
import '../../models/product_material_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/app_bar_widget.dart';

class MaterialsPage extends ConsumerWidget {
  const MaterialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Materiales',
          showBack: true,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            tabs: [
              Tab(text: 'Materiales'),
              Tab(text: 'Registro de uso'),
            ],
          ),
        ),
        body: const TabBarView(children: [_MaterialsTab(), _UsageTab()]),
      ),
    );
  }
}

// Tab de lista de materiales
class _MaterialsTab extends ConsumerWidget {
  const _MaterialsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(materialProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.materials.isEmpty
          ? Center(
              child: Text(
                'No hay materiales registrados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.materials.length,
              itemBuilder: (context, index) {
                final m = state.materials[index];
                return _MaterialCard(
                  material: m,
                  onEdit: () => _showDialog(context, m),
                );
              },
            ),
    );
  }

  void _showDialog(BuildContext context, MaterialModel? material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MaterialDialog(material: material),
    );
  }
}

// Tab de registro de uso de materiales por producto
class _UsageTab extends ConsumerStatefulWidget {
  const _UsageTab();

  @override
  ConsumerState<_UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends ConsumerState<_UsageTab> {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RegisterUsageSheet(
        productId: _selectedProductId!,
        onRegistered: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  void _showEditSheet(ProductMaterialModel entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditUsageSheet(
        entry: entry,
        onEdited: () => _loadUsageLog(_selectedProductId!),
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
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              onPressed: _showRegisterSheet,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Selector de producto
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedProductId,
                  isExpanded: true,
                  hint: const Text('Selecciona un producto'),
                  items: products
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProductId = val;
                      _usageLog = [];
                    });
                    if (val != null) _loadUsageLog(val);
                  },
                ),
              ),
            ),
          ),

          if (_selectedProductId == null)
            Expanded(
              child: Center(
                child: Text(
                  'Selecciona un producto para ver\nel registro de uso de materiales',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_usageLog.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Sin registros de uso',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _usageLog.length,
                itemBuilder: (context, index) {
                  final entry = _usageLog[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.materialName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Cantidad: ${formatNumber(entry.quantityUsed)}  •  Bs. ${entry.pricePerUnit.toStringAsFixed(2)}/u',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botón editar registro
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () => _showEditSheet(entry),
                        ),
                      ],
                    ),
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
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterialId == null) return;

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .registerUsage(
          productId: widget.productId,
          materialId: _selectedMaterialId!,
          quantityUsed: double.tryParse(_quantityController.text.trim()) ?? 0,
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

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrar el uso de un material',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Selector de material con stock visible
            DropdownButtonFormField<int>(
              value: _selectedMaterialId,
              decoration: const InputDecoration(labelText: 'Material'),
              items: materials
                  .map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedMaterialId = val),
              validator: (v) => v == null ? 'Selecciona un material' : null,
            ),
            // Muestra el stock disponible del material seleccionado
            if (_selectedMaterialId != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Stock disponible: ${formatNumber(materials.where((m) => m.id == _selectedMaterialId).first.stock)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Cantidad con validación de stock
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad utilizada',
                hintText: '0',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final qty = double.tryParse(v);
                if (qty == null || qty <= 0) return 'Cantidad inválida';
                if (_selectedMaterialId != null) {
                  final material = ref
                      .read(materialProvider)
                      .materials
                      .where((m) => m.id == _selectedMaterialId)
                      .firstOrNull;
                  if (material != null && qty > material.stock) {
                    return 'Cantidad máxima disponible: ${formatNumber(material.stock)}';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Error del servidor
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Botones cancelar y registrar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _register,
                    child: const Text(
                      'Registrar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
  String? _error;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Precarga la cantidad actual formateada
    _quantityController = TextEditingController(
      text: formatNumber(widget.entry.quantityUsed),
    );
    _quantityController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final changed =
        _quantityController.text.trim() !=
        formatNumber(widget.entry.quantityUsed);
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .editUsage(
          recordId: widget.entry.id,
          newQuantity: double.tryParse(_quantityController.text.trim()) ?? 0,
        );

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
    final availableStock = (material?.stock ?? 0) + widget.entry.quantityUsed;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Editar registro de uso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // Muestra el material que se está editando
            Text(
              widget.entry.materialName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Campo de cantidad
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nueva cantidad',
                hintText: '0',
                helperText:
                    'Máximo disponible: ${formatNumber(availableStock)}',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final qty = double.tryParse(v);
                if (qty == null || qty <= 0) return 'Cantidad inválida';
                if (qty > availableStock) {
                  return 'Máximo: ${formatNumber(availableStock)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Error del servidor
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Botones cancelar y guardar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasChanges ? _save : null,
                    child: const Text(
                      'Guardar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta de material en la lista
class _MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onEdit;

  const _MaterialCard({required this.material, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (material.description != null &&
                    material.description!.isNotEmpty)
                  Text(
                    material.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Stock: ${formatNumber(material.stock)}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bs. ${material.pricePerUnit.toStringAsFixed(2)}/u',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: material.isActive
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    material.isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: material.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
