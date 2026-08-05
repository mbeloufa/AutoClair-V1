import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_care_models.dart';
import 'vehicle_care_service.dart';
import 'vehicle_event_catalog.dart';
import 'vehicle_event_notification_service.dart';
import 'vehicle_event_reminder.dart';

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
  final _notificationService = VehicleEventNotificationService.instance;
  final _titleController = TextEditingController();
  final _mileageController = TextEditingController();
  final _amountController = TextEditingController();
  final _providerController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _categoryCode;
  late String _subcategoryCode;
  String _status = 'COMPLETED';
  DateTime _occurredAt = DateTime.now();
  VehicleEventDocumentOption? _selectedDocument;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 7;
  bool _saving = false;

  VehicleEventCategory get _category =>
      VehicleEventCatalog.categoryByCode(_categoryCode);

  VehicleEventSubcategory get _subcategory =>
      VehicleEventCatalog.subcategoryByCode(
        _subcategoryCode,
        categoryCode: _categoryCode,
      );

  @override
  void initState() {
    super.initState();
    final initial = VehicleEventCatalog.fromEventType(
      widget.initialEventType ?? 'MAINTENANCE',
    );
    _categoryCode = initial.category.code;
    _subcategoryCode = initial.subcategory.code;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mileageController.dispose();
    _amountController.dispose();
    _providerController.dispose();
    _locationController.dispose();
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

  Future<void> _selectCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _ChoiceSheet(
        title: 'Choisir une catégorie',
        children: [
          for (final category in VehicleEventCatalog.categories)
            ListTile(
              key: ValueKey('event-category-${category.code}'),
              leading: Icon(category.icon),
              title: Text(category.label),
              trailing: category.code == _categoryCode
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              selected: category.code == _categoryCode,
              onTap: () => Navigator.of(sheetContext).pop(category.code),
            ),
        ],
      ),
    );

    if (selected == null || selected == _categoryCode || !mounted) return;
    final category = VehicleEventCatalog.categoryByCode(selected);
    setState(() {
      _categoryCode = category.code;
      _subcategoryCode = category.subcategories.first.code;
    });
  }

  Future<void> _selectSubcategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _ChoiceSheet(
        title: 'Préciser l’opération',
        children: [
          for (final subcategory in _category.subcategories)
            ListTile(
              key: ValueKey('event-subcategory-${subcategory.code}'),
              title: Text(subcategory.label),
              trailing: subcategory.code == _subcategoryCode
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              selected: subcategory.code == _subcategoryCode,
              onTap: () => Navigator.of(sheetContext).pop(subcategory.code),
            ),
        ],
      ),
    );

    if (selected == null || selected == _subcategoryCode || !mounted) return;
    setState(() => _subcategoryCode = selected);
  }

  Future<void> _attachNewDocument() async {
    await context.push<void>('/documents/new');
    if (!mounted) return;
    await _selectExistingDocument(
      emptyMessage: 'Le nouveau document apparaît dès son enregistrement.',
    );
  }

  Future<void> _selectExistingDocument({String? emptyMessage}) async {
    List<VehicleEventDocumentOption> documents;
    try {
      documents = await _service.fetchLinkableDocuments(widget.vehicleId);
    } on VehicleCareException catch (error) {
      if (mounted) _message(error.message);
      return;
    }
    if (!mounted) return;

    if (documents.isEmpty) {
      _message(emptyMessage ?? 'Aucun document disponible à lier.');
      return;
    }

    final selected = await showModalBottomSheet<VehicleEventDocumentOption>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ChoiceSheet(
        title: 'Lier un document existant',
        children: [
          for (final document in documents)
            ListTile(
              key: ValueKey('event-document-${document.id}'),
              leading: const Icon(Icons.description_outlined),
              title: Text(document.displayLabel),
              subtitle: Text(
                '${document.statusLabel} · ${_formatDate(document.createdAt)}',
              ),
              trailing: document.id == _selectedDocument?.id
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(document),
            ),
        ],
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedDocument = selected);
    }
  }

  Future<void> _openNearbyGarages() async {
    await context.push<void>('/nearby');
    if (!mounted) return;
    _message(
      'Vous pouvez renseigner le garage et son adresse dans les champs ci-dessus.',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    if (_status == 'PLANNED' && _reminderEnabled) {
      final reminderAt = vehicleEventReminderAt(
        eventDate: _occurredAt,
        daysBefore: _reminderDaysBefore,
      );
      if (!reminderAt.isAfter(DateTime.now())) {
        _message('Choisissez une date plus éloignée ou un délai plus court.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_status == 'PLANNED' && _reminderEnabled) {
        await _notificationService.ensurePermission();
      }

      final customTitle = _titleController.text.trim();
      final eventTitle = customTitle.isEmpty
          ? _subcategory.defaultTitle
          : customTitle;
      final saved = await _service.recordEvent(
        vehicleId: widget.vehicleId,
        eventType: _subcategory.eventType,
        categoryCode: _category.code,
        subcategoryCode: _subcategory.code,
        title: eventTitle,
        occurredAt: _occurredAt,
        status: _status,
        mileage: _optionalInteger(_mileageController.text),
        amount: _optionalDecimal(_amountController.text),
        providerName: _providerController.text,
        locationText: _locationController.text,
        description: _descriptionController.text,
        sourceDocumentId: _selectedDocument?.id,
        reminderEnabled: _status == 'PLANNED' && _reminderEnabled,
        reminderDaysBefore: _status == 'PLANNED' && _reminderEnabled
            ? _reminderDaysBefore
            : null,
      );

      var reminderWarning = false;
      if (_status == 'PLANNED' && _reminderEnabled) {
        try {
          await _notificationService.scheduleReminder(
            vehicleId: widget.vehicleId,
            eventKey: saved.notificationKey,
            vehicleLabel: 'Votre véhicule',
            eventTitle: eventTitle,
            eventDate: _occurredAt,
            daysBefore: _reminderDaysBefore,
          );
        } on VehicleEventNotificationException catch (error) {
          reminderWarning = true;
          if (mounted) _message(error.message);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminderWarning
                ? 'Événement ajouté, mais le rappel système n’a pas été programmé.'
                : _status == 'PLANNED'
                ? 'Événement prévu ajouté.'
                : 'Événement ajouté au carnet.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on VehicleEventNotificationException catch (error) {
      if (mounted) _message(error.message);
    } on VehicleCareException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              Text(
                'Que s’est-il passé ?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                'Choisissez une catégorie, puis l’opération.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              _ChoiceField(
                key: const ValueKey('event-category-selector'),
                label: 'Catégorie',
                icon: _category.icon,
                value: _category.label,
                enabled: !_saving,
                onTap: _selectCategory,
              ),
              const SizedBox(height: 14),
              _ChoiceField(
                key: ValueKey('event-subcategory-$_categoryCode'),
                label: 'Opération',
                icon: Icons.build_outlined,
                value: _subcategory.label,
                enabled: !_saving,
                onTap: _selectSubcategory,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Précision (facultatif)',
                  hintText: _subcategory.defaultTitle,
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _saving ? null : _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _status == 'PLANNED'
                        ? 'Date prévue'
                        : 'Date de réalisation',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDate(_occurredAt)),
                ),
              ),
              const SizedBox(height: 16),
              Text('État', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const ValueKey('event-status-completed'),
                    selected: _status == 'COMPLETED',
                    onSelected: _saving
                        ? null
                        : (_) => setState(() {
                            _status = 'COMPLETED';
                            _reminderEnabled = false;
                          }),
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Réalisé'),
                  ),
                  ChoiceChip(
                    key: const ValueKey('event-status-planned'),
                    selected: _status == 'PLANNED',
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _status = 'PLANNED'),
                    avatar: const Icon(Icons.schedule_outlined, size: 18),
                    label: const Text('Prévu'),
                  ),
                ],
              ),
              if (_status == 'PLANNED') ...[
                const SizedBox(height: 14),
                Material(
                  key: const ValueKey('event-reminder-section'),
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        key: const ValueKey('event-reminder-switch'),
                        value: _reminderEnabled,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _reminderEnabled = value),
                        title: const Text('Me le rappeler'),
                        subtitle: const Text(
                          'Notification facultative avant la date prévue.',
                        ),
                        secondary: const Icon(Icons.notifications_outlined),
                      ),
                      if (_reminderEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Me prévenir avant :'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final days
                                      in supportedVehicleEventReminderDays)
                                    ChoiceChip(
                                      key: ValueKey(
                                        'event-reminder-days-$days',
                                      ),
                                      selected: _reminderDaysBefore == days,
                                      onSelected: _saving
                                          ? null
                                          : (_) => setState(
                                              () => _reminderDaysBefore = days,
                                            ),
                                      label: Text('$days j'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _status == 'PLANNED'
                      ? 'Kilométrage prévu (facultatif)'
                      : 'Kilométrage (facultatif)',
                  suffixText: 'km',
                  prefixIcon: const Icon(Icons.speed_outlined),
                ),
                validator: _validateOptionalInteger,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _status == 'PLANNED'
                      ? 'Budget prévu (facultatif)'
                      : 'Prix (facultatif)',
                  suffixText: '€',
                  prefixIcon: const Icon(Icons.euro_outlined),
                ),
                validator: _validateOptionalDecimal,
              ),
              const SizedBox(height: 20),
              Text(
                'Garage ou lieu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _providerController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Garage ou prestataire (facultatif)',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Adresse ou lieu (facultatif)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('event-nearby-garages'),
                onPressed: _saving ? null : _openNearbyGarages,
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Rechercher autour de moi'),
              ),
              const SizedBox(height: 20),
              Text('Document', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                'Ajoutez une preuve ou liez un document déjà enregistré.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              if (_selectedDocument != null) ...[
                Container(
                  key: const ValueKey('event-selected-document'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.softPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_selectedDocument!.displayLabel)),
                      IconButton(
                        key: const ValueKey('event-preview-document'),
                        tooltip: 'Prévisualiser le document',
                        onPressed: _saving
                            ? null
                            : () => context.push<void>(
                                '/history/${_selectedDocument!.id}/analysis',
                              ),
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                      IconButton(
                        key: const ValueKey('event-remove-document'),
                        tooltip: 'Retirer le document',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _selectedDocument = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                key: const ValueKey('event-document-new'),
                onPressed: _saving ? null : _attachNewDocument,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Joindre un nouveau document'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('event-document-existing'),
                onPressed: _saving ? null : _selectExistingDocument,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Lier un document existant'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note (facultatif)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _saving
                      ? 'Enregistrement…'
                      : _status == 'PLANNED'
                      ? 'Ajouter comme prévu'
                      : 'Ajouter au carnet',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _optionalInteger(String value) {
  final text = value.trim();
  return text.isEmpty ? null : int.tryParse(text);
}

double? _optionalDecimal(String value) {
  final text = value.trim().replaceAll(',', '.');
  return text.isEmpty ? null : double.tryParse(text);
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String? _validateOptionalInteger(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  return parsed == null || parsed < 0 ? 'Kilométrage invalide.' : null;
}

String? _validateOptionalDecimal(String? value) {
  final text = value?.trim().replaceAll(',', '.') ?? '';
  if (text.isEmpty) return null;
  final parsed = double.tryParse(text);
  return parsed == null || parsed < 0 ? 'Montant invalide.' : null;
}
