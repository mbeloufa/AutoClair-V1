import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'compliance_models.dart';
import 'compliance_service.dart';

class VehicleCompliancePage extends StatefulWidget {
  const VehicleCompliancePage({super.key});

  @override
  State<VehicleCompliancePage> createState() => _VehicleCompliancePageState();
}

class _VehicleCompliancePageState extends State<VehicleCompliancePage> {
  final _vehicleService = VehicleService();
  final _service = ComplianceService();

  List<Vehicle> _vehicles = const [];
  String? _vehicleId;
  ComplianceOverview? _overview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      final selected = vehicles.isEmpty
          ? null
          : vehicles.firstWhere(
              (vehicle) => vehicle.isPrimary,
              orElse: () => vehicles.first,
            );
      setState(() {
        _vehicles = vehicles;
        _vehicleId = selected?.id;
      });
      await _loadOverview();
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadOverview() async {
    final id = _vehicleId;
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final overview = await _service.loadOverview(id);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } on ComplianceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _changeVehicle(String? value) async {
    if (value == null) return;
    setState(() {
      _vehicleId = value;
      _overview = null;
    });
    await _loadOverview();
  }

  Future<void> _addDeadline() async {
    final vehicleId = _vehicleId;
    if (vehicleId == null) return;
    final draft = await showModalBottomSheet<_DeadlineDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _DeadlineEditor(),
    );
    if (draft == null) return;
    try {
      await _service.saveManualItem(
        vehicleId: vehicleId,
        type: draft.type,
        title: draft.title,
        dueDate: draft.dueDate,
        message: draft.message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Échéance ajoutée.')));
      await _loadOverview();
    } on ComplianceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _complete(ComplianceItem item) async {
    try {
      await _service.completeItem(item.id);
      await _loadOverview();
    } on ComplianceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le lien officiel n'a pas pu être ouvert."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    return Scaffold(
      appBar: AppBar(title: const Text('À vérifier')),
      floatingActionButton: _vehicleId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addDeadline,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Ajouter une échéance'),
            ),
      body: RefreshIndicator(
        onRefresh: _loadOverview,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            const _ComplianceIntro(),
            const SizedBox(height: 16),
            if (_vehicles.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const ValueKey('compliance-vehicle-selector'),
                initialValue: _vehicleId,
                decoration: const InputDecoration(labelText: 'Véhicule'),
                items: _vehicles
                    .map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text(vehicle.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _changeVehicle,
              ),
            if (_loading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
            ] else if (_vehicles.isEmpty) ...[
              const SizedBox(height: 20),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ajoutez un véhicule pour suivre ses échéances.'),
                ),
              ),
            ] else if (_error != null) ...[
              const SizedBox(height: 20),
              _ComplianceError(message: _error!, onRetry: _loadOverview),
            ] else if (overview != null) ...[
              const SizedBox(height: 20),
              _ComplianceSection(
                title: 'À faire rapidement',
                emptyMessage: 'Aucune alerte urgente détectée.',
                items: overview.urgent,
                urgent: true,
                onComplete: _complete,
                onOpenUrl: _openUrl,
              ),
              const SizedBox(height: 20),
              _ComplianceSection(
                title: 'Prochainement',
                emptyMessage: 'Aucune échéance à venir.',
                items: overview.upcoming,
                urgent: false,
                onComplete: _complete,
                onOpenUrl: _openUrl,
              ),
              const SizedBox(height: 20),
              _OfficialTools(onOpenUrl: _openUrl),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComplianceIntro extends StatelessWidget {
  const _ComplianceIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: AppColors.warning,
            size: 30,
          ),
          SizedBox(height: 10),
          Text(
            'Centralisez les échéances qui évitent une amende, une contre-visite ou un oubli.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Un rapprochement de rappel reste une alerte à vérifier avec le VIN, jamais une confirmation automatique.',
          ),
        ],
      ),
    );
  }
}

class _ComplianceSection extends StatelessWidget {
  const _ComplianceSection({
    required this.title,
    required this.emptyMessage,
    required this.items,
    required this.urgent,
    required this.onComplete,
    required this.onOpenUrl,
  });

  final String title;
  final String emptyMessage;
  final List<ComplianceItem> items;
  final bool urgent;
  final ValueChanged<ComplianceItem> onComplete;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(emptyMessage)
            else
              for (final item in items) ...[
                _ComplianceTile(
                  item: item,
                  urgent: urgent,
                  onComplete: () => onComplete(item),
                  onOpenUrl: item.sourceUrl == null
                      ? null
                      : () => onOpenUrl(item.sourceUrl!),
                ),
                if (item != items.last) const Divider(height: 24),
              ],
          ],
        ),
      ),
    );
  }
}

class _ComplianceTile extends StatelessWidget {
  const _ComplianceTile({
    required this.item,
    required this.urgent,
    required this.onComplete,
    this.onOpenUrl,
  });

  final ComplianceItem item;
  final bool urgent;
  final VoidCallback onComplete;
  final VoidCallback? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.error : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(item.type), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(item.message),
                  if (item.dueDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.isOverdue
                          ? 'Échéance dépassée : ${_formatDate(item.dueDate!)}'
                          : 'Échéance : ${_formatDate(item.dueDate!)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (item.confidence != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Confiance du rapprochement : ${(item.confidence! * 100).round()} %',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onOpenUrl != null)
              OutlinedButton.icon(
                onPressed: onOpenUrl,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Voir la source'),
              ),
            if (!item.id.startsWith('recall-') &&
                !item.id.startsWith('schedule-'))
              FilledButton.tonal(
                onPressed: onComplete,
                child: const Text('Marquer comme fait'),
              ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'TECHNICAL_CONTROL' => Icons.fact_check_outlined,
    'INSURANCE' => Icons.shield_outlined,
    'RECALL' => Icons.campaign_outlined,
    'MAINTENANCE' => Icons.build_circle_outlined,
    'ZFE' => Icons.eco_outlined,
    _ => Icons.event_outlined,
  };

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _OfficialTools extends StatelessWidget {
  const _OfficialTools({required this.onOpenUrl});

  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Services officiels',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onOpenUrl('https://histovec.interieur.gouv.fr/'),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Ouvrir HistoVec'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onOpenUrl('https://rappel.conso.gouv.fr/'),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Consulter RappelConso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineEditor extends StatefulWidget {
  const _DeadlineEditor();

  @override
  State<_DeadlineEditor> createState() => _DeadlineEditorState();
}

class _DeadlineEditorState extends State<_DeadlineEditor> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _type = 'INSURANCE';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (result != null) setState(() => _dueDate = result);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un titre à l’échéance.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _DeadlineDraft(
        type: _type,
        title: title,
        message: _messageController.text.trim(),
        dueDate: _dueDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter une échéance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'INSURANCE', child: Text('Assurance')),
                DropdownMenuItem(
                  value: 'TECHNICAL_CONTROL',
                  child: Text('Contrôle technique'),
                ),
                DropdownMenuItem(value: 'DOCUMENT', child: Text('Document')),
                DropdownMenuItem(value: 'ZFE', child: Text('Crit’Air / ZFE')),
                DropdownMenuItem(value: 'OTHER', child: Text('Autre')),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (facultatif)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Échéance : ${_formatDate(_dueDate)}'),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _DeadlineDraft {
  const _DeadlineDraft({
    required this.type,
    required this.title,
    required this.message,
    required this.dueDate,
  });

  final String type;
  final String title;
  final String message;
  final DateTime dueDate;
}

class _ComplianceError extends StatelessWidget {
  const _ComplianceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
