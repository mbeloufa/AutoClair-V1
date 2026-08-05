import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_brand_catalog.dart';
import 'vehicle_brand_logo.dart';

class VehicleBrandPickerField extends StatefulWidget {
  const VehicleBrandPickerField({
    required this.controller,
    required this.validator,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool enabled;

  @override
  State<VehicleBrandPickerField> createState() =>
      _VehicleBrandPickerFieldState();
}

class _VehicleBrandPickerFieldState extends State<VehicleBrandPickerField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(VehicleBrandPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _pickBrand() async {
    if (!widget.enabled) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _BrandSelectionSheet(),
    );

    if (!mounted || selected == null) return;

    if (selected == _BrandSelectionSheet.otherValue) {
      await _enterOtherBrand();
      return;
    }

    widget.controller.text = selected;
  }

  Future<void> _enterOtherBrand() async {
    final customController = TextEditingController(
      text: VehicleBrandCatalog.isKnown(widget.controller.text)
          ? ''
          : widget.controller.text.trim(),
    );

    try {
      final customBrand = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Autre marque'),
          content: TextField(
            controller: customController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Nom de la marque',
              hintText: 'Ex. Lancia',
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = customController.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(dialogContext).pop(trimmed);
                }
              },
              child: const Text('Utiliser cette marque'),
            ),
          ],
        ),
      );

      if (!mounted || customBrand == null) return;
      widget.controller.text = customBrand.trim();
    } finally {
      customController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.controller.text.trim();

    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      enabled: widget.enabled,
      validator: widget.validator,
      onTap: _pickBrand,
      decoration: InputDecoration(
        labelText: 'Marque',
        hintText: 'Choisir la marque',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(8),
          child: VehicleBrandLogo(brand: brand, size: 40),
        ),
        suffixIcon: const Icon(Icons.expand_more_rounded),
      ),
    );
  }
}

class _BrandSelectionSheet extends StatefulWidget {
  const _BrandSelectionSheet();

  static const otherValue = '__other_brand__';

  @override
  State<_BrandSelectionSheet> createState() => _BrandSelectionSheetState();
}

class _BrandSelectionSheetState extends State<_BrandSelectionSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brands = VehicleBrandCatalog.search(_query);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + keyboardInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Choisir la marque',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Le logo et le nom seront affichés dans la fiche du véhicule.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Rechercher une marque',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: brands.length + 1,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  if (index == brands.length) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      leading: const VehicleBrandLogo(brand: 'Autre', size: 44),
                      title: const Text('Autre marque'),
                      subtitle: const Text('Saisir librement son nom'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_BrandSelectionSheet.otherValue),
                    );
                  }

                  final brand = brands[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    leading: VehicleBrandLogo(brand: brand.name, size: 44),
                    title: Text(brand.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(brand.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
