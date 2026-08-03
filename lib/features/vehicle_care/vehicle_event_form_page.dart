import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_care_models.dart';
import 'vehicle_care_service.dart';

class VehicleEventFormPage extends StatefulWidget {
  const VehicleEventFormPage({
    required this.vehicleId,
    this.initialEventType,
    super.key,
  });

  final String vehicleId;
  final String? initialEventType;

  @override
  State<VehicleEventFormPage> createState() => _VehicleEventFormPageState();
}

class _VehicleEventFormPageState extends State<VehicleEventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = VehicleCareService();
  final _titleController = TextEditingController();
  final _mileageController = TextEditingController();
  final _amountController = TextEditingController();
  final _providerController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _eventType;
  String _status = 'COMPLETED';
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;

  static const _eventTypes = <String>[
    'MAINTENANCE',
    'REPAIR',
    'INSPECTION',
    'REINSPECTION',
    'TYRES',
    'FUEL',
    'CHARGING',
    'INSURANCE',
    'WARRANTY',
    'ACCIDENT',
    'RECALL',
    'EQUIPMENT',
    'CONDITION',
    'ADMINISTRATIVE',
    'PURCHASE',
    'SALE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _eventType = _eventTypes.contains(widget.initialEventType)
        ? widget.initialEventType!
        : 'MAINTENANCE';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mileageController.dispose();
    _amountController.dispose();
    _providerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: "Date de l'événement",
    );
    if (date != null && mounted) {
      setState(() {
        _occurredAt = DateTime(date.year, date.month, date.day, 12);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _service.recordEvent(
        vehicleId: widget.vehicleId,
        eventType: _eventType,
        title: _titleController.text,
        occurredAt: _occurredAt,
        status: _status,
        mileage: _optionalInteger(_mileageController.text),
        amount: _optionalDecimal(_amountController.text),
        providerName: _providerController.text,
        description: _descriptionController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Événement ajouté au carnet.')),
      );
      Navigator.of(context).pop(true);
    } on VehicleCareException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un événement')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _InfoCard(
                icon: Icons.edit_calendar_outlined,
                title: 'Ajout rapide',
                message:
                    'Le kilométrage et le montant sont facultatifs. Un montant '
                    'créera automatiquement une dépense associée.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _eventType,
                decoration: const InputDecoration(
                  labelText: "Type d'événement",
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final type in _eventTypes)
                    DropdownMenuItem(
                      value: type,
                      child: Text(eventTypeLabel(type)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _eventType = value);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Ex. Vidange et filtre à huile',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Saisissez un titre.'
                    : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _saving ? null : _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDate(_occurredAt)),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'COMPLETED',
                    label: Text('Réalisé'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: 'PLANNED',
                    label: Text('Prévu'),
                    icon: Icon(Icons.schedule_outlined),
                  ),
                  ButtonSegment(
                    value: 'RECOMMENDED',
                    label: Text('Conseillé'),
                    icon: Icon(Icons.lightbulb_outline),
                  ),
                ],
                selected: {_status},
                showSelectedIcon: false,
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() => _status = selection.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilométrage (facultatif)',
                  suffixText: 'km',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
                validator: _validateOptionalInteger,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant (facultatif)',
                  suffixText: '€',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
                validator: _validateOptionalDecimal,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _providerController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Garage ou intervenant (facultatif)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Notes (facultatif)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_task_outlined),
                label: Text(
                  _saving ? 'Enregistrement...' : 'Ajouter au carnet',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

int? _optionalInteger(String value) {
  final text = value.trim();
  return text.isEmpty ? null : int.tryParse(text.replaceAll(' ', ''));
}

double? _optionalDecimal(String value) {
  final text = value.trim();
  return text.isEmpty
      ? null
      : double.tryParse(text.replaceAll(' ', '').replaceAll(',', '.'));
}

String? _validateOptionalInteger(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text.replaceAll(' ', ''));
  return parsed == null || parsed < 0 ? 'Kilométrage invalide.' : null;
}

String? _validateOptionalDecimal(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = double.tryParse(text.replaceAll(' ', '').replaceAll(',', '.'));
  return parsed == null || parsed < 0 ? 'Montant invalide.' : null;
}
