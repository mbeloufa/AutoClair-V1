import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_case_models.dart';
import 'legal_case_scope.dart';
import 'legal_case_service.dart';

class LegalSupportPage extends StatefulWidget {
  const LegalSupportPage({super.key});

  @override
  State<LegalSupportPage> createState() => _LegalSupportPageState();
}

class _LegalSupportPageState extends State<LegalSupportPage> {
  final _service = LegalCaseService();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _additionalController = TextEditingController();

  List<LegalVehicleOption> _vehicles = const [];
  List<LegalDocumentOption> _documents = const [];
  LegalVehicleOption? _vehicle;
  LegalCaseCategory _category = LegalCaseCategory.professionalPurchase;
  String _counterpartyType = 'professional';
  DateTime? _eventDate;
  bool _writtenComplaint = false;
  bool _bodilyInjury = false;
  bool _courtStarted = false;
  bool _criminalIssue = false;
  bool _crossBorder = false;
  final Set<String> _selectedDocuments = <String>{};

  bool _loading = true;
  bool _loadingDocuments = false;
  bool _processing = false;
  String? _error;
  String? _caseId;
  LegalAnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_refreshScope);
    _load();
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_refreshScope)
      ..dispose();
    _amountController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  void _refreshScope() {
    if (mounted) setState(() {});
  }

  LegalScopeDecision get _scope => LegalScopeDecision.evaluate(
    category: _category,
    counterpartyType: _counterpartyType,
    description: _descriptionController.text,
    bodilyInjury: _bodilyInjury,
    courtStarted: _courtStarted,
    criminalIssue: _criminalIssue,
    crossBorder: _crossBorder,
  );

  Future<void> _load() async {
    try {
      final vehicles = await _service.fetchVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _vehicle = vehicles.isEmpty ? null : vehicles.first;
        _loading = false;
      });
      if (_vehicle != null) {
        await _loadDocuments(_vehicle!.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadDocuments(String vehicleId) async {
    setState(() {
      _loadingDocuments = true;
      _selectedDocuments.clear();
    });
    try {
      final documents = await _service.fetchDocuments(vehicleId);
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _loadingDocuments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _documents = const [];
        _loadingDocuments = false;
        _error = error.toString();
      });
    }
  }

  void _selectCategory(LegalCaseCategory category) {
    setState(() {
      _category = category;
      _counterpartyType = switch (category) {
        LegalCaseCategory.professionalPurchase => 'professional',
        LegalCaseCategory.garageRepair => 'garage',
        LegalCaseCategory.warrantyRefusal => 'warranty_provider',
        LegalCaseCategory.consumerMediation => 'professional',
        LegalCaseCategory.other => 'unknown',
      };
      _result = null;
      _caseId = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 15),
      lastDate: now,
      initialDate: _eventDate ?? now,
    );
    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _createAndAnalyze() async {
    final vehicle = _vehicle;
    if (vehicle == null) {
      _showMessage(
        'Ajoutez ou sélectionnez un véhicule avant de créer le dossier.',
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showMessage('Décrivez brièvement ce qui s’est passé.');
      return;
    }

    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    if (amountText.isNotEmpty && amount == null) {
      _showMessage('Le montant indiqué n’est pas valide.');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });

    try {
      final caseId = await _service.createCase(
        vehicle: vehicle,
        category: _category,
        counterpartyType: _counterpartyType,
        description: _descriptionController.text,
        eventDate: _eventDate,
        amountEur: amount,
        writtenComplaint: _writtenComplaint,
        bodilyInjury: _bodilyInjury,
        courtStarted: _courtStarted,
        criminalIssue: _criminalIssue,
        crossBorder: _crossBorder,
        documentIds: _selectedDocuments,
      );
      final result = await _service.analyzeCase(caseId);
      if (!mounted) return;
      setState(() {
        _caseId = caseId;
        _result = result;
        _processing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _reanalyze() async {
    final caseId = _caseId;
    final addition = _additionalController.text.trim();
    if (caseId == null || addition.isEmpty) return;

    setState(() => _processing = true);
    try {
      final result = await _service.appendInformationAndAnalyze(
        caseId: caseId,
        additionalInformation: addition,
      );
      if (!mounted) return;
      setState(() {
        _additionalController.clear();
        _result = result;
        _processing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _deleteCurrentCase() async {
    final caseId = _caseId;
    if (caseId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce dossier ?'),
        content: const Text(
          'Les faits, liens vers les pièces et analyses de ce dossier Litiges & démarches seront supprimés. Vos documents AutoClair d’origine sont conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      await _service.deleteCase(caseId);
      if (!mounted) return;
      setState(() {
        _caseId = null;
        _result = null;
        _processing = false;
      });
      _showMessage('Dossier Litiges & démarches supprimé.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = error.toString();
      });
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Litiges & démarches')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const ValueKey('legal-support-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _introCard(),
                const SizedBox(height: 16),
                _vehicleCard(),
                const SizedBox(height: 16),
                _categoryCard(),
                const SizedBox(height: 16),
                _situationCard(),
                const SizedBox(height: 16),
                _documentsCard(),
                const SizedBox(height: 16),
                _scopeCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorCard(_error!),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('legal-support-analyze'),
                  onPressed: _processing ? null : _createAndAnalyze,
                  icon: _processing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(
                    _scope.canAnalyze
                        ? 'Analyser mon dossier'
                        : 'Préparer mon dossier',
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 22),
                  _resultView(_result!),
                ],
              ],
            ),
    );
  }

  Widget _introCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assistant IA AutoClair • V1 en évaluation',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Comprendre votre situation, organiser votre dossier et préparer vos démarches.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'AutoClair distingue les faits, les informations manquantes et les sources officielles. '
              'L’analyse automatisée ne remplace pas l’avis d’un professionnel du droit.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleCard() {
    return _sectionCard(
      title: '1. Véhicule concerné',
      child: _vehicles.isEmpty
          ? const Text(
              'Aucun véhicule enregistré. Ajoutez d’abord votre véhicule dans AutoClair.',
            )
          : DropdownButtonFormField<LegalVehicleOption>(
              initialValue: _vehicle,
              decoration: const InputDecoration(labelText: 'Véhicule'),
              items: _vehicles
                  .map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle,
                      child: Text(vehicle.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _processing
                  ? null
                  : (vehicle) async {
                      if (vehicle == null) return;
                      setState(() {
                        _vehicle = vehicle;
                        _result = null;
                        _caseId = null;
                      });
                      await _loadDocuments(vehicle.id);
                    },
            ),
    );
  }

  Widget _categoryCard() {
    return _sectionCard(
      title: '2. Quel est votre problème ?',
      child: Column(
        children: LegalCaseCategory.values
            .map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: _category == category
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('legal-category-${category.dbValue}'),
                    onTap: _processing ? null : () => _selectCategory(category),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _category == category
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(category.description),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _situationCard() {
    return _sectionCard(
      title: '3. Votre situation',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(
              'legal-counterparty-${_category.dbValue}-$_counterpartyType',
            ),
            initialValue: _counterpartyType,
            decoration: const InputDecoration(labelText: 'Interlocuteur'),
            items: const [
              DropdownMenuItem(
                value: 'professional',
                child: Text('Vendeur professionnel'),
              ),
              DropdownMenuItem(
                value: 'garage',
                child: Text('Garage / réparateur'),
              ),
              DropdownMenuItem(
                value: 'manufacturer',
                child: Text('Constructeur'),
              ),
              DropdownMenuItem(
                value: 'warranty_provider',
                child: Text('Organisme de garantie'),
              ),
              DropdownMenuItem(
                value: 'private_individual',
                child: Text('Vendeur particulier'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Autre')),
              DropdownMenuItem(value: 'unknown', child: Text('Je ne sais pas')),
            ],
            onChanged: _processing
                ? null
                : (value) => setState(() {
                    _counterpartyType = value ?? 'unknown';
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('legal-issue-description'),
            controller: _descriptionController,
            minLines: 4,
            maxLines: 8,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Que s’est-il passé ?',
              hintText:
                  'Décrivez les faits, les dates importantes, le problème et la réponse du professionnel.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _eventDate == null
                        ? 'Ajouter une date'
                        : '${_eventDate!.day.toString().padLeft(2, '0')}/'
                              '${_eventDate!.month.toString().padLeft(2, '0')}/'
                              '${_eventDate!.year}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant concerné',
                    suffixText: '€',
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('J’ai déjà envoyé une réclamation écrite'),
            value: _writtenComplaint,
            onChanged: _processing
                ? null
                : (value) => setState(() => _writtenComplaint = value),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Vérification du périmètre V1'),
            subtitle: const Text(
              'Signalez une situation qui nécessite un professionnel.',
            ),
            children: [
              _riskSwitch(
                'Dommage corporel / personne blessée',
                _bodilyInjury,
                (value) => _bodilyInjury = value,
              ),
              _riskSwitch(
                'Procédure judiciaire déjà engagée',
                _courtStarted,
                (value) => _courtStarted = value,
              ),
              _riskSwitch(
                'Aspect pénal, fraude ou infraction importante',
                _criminalIssue,
                (value) => _criminalIssue = value,
              ),
              _riskSwitch(
                'Litige impliquant plusieurs pays',
                _crossBorder,
                (value) => _crossBorder = value,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskSwitch(String title, bool value, ValueChanged<bool> assign) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: _processing
          ? null
          : (next) => setState(() {
              assign(next);
            }),
    );
  }

  Widget _documentsCard() {
    return _sectionCard(
      title: '4. Documents du dossier',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sélectionnez uniquement les pièces utiles. Les informations extraites automatiquement restent des points à vérifier tant que vous ne les avez pas confirmées.',
          ),
          const SizedBox(height: 10),
          if (_loadingDocuments)
            const Center(child: CircularProgressIndicator())
          else if (_documents.isEmpty)
            const Text('Aucun document lié à ce véhicule pour le moment.')
          else
            ..._documents.map(
              (document) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selectedDocuments.contains(document.id),
                title: Text(document.label),
                subtitle: Text(
                  document.analyzed
                      ? 'Analyse AutoClair disponible'
                      : 'Document non analysé ou analyse en cours',
                ),
                onChanged: _processing
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selectedDocuments.add(document.id);
                        } else {
                          _selectedDocuments.remove(document.id);
                        }
                      }),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('legal-support-add-document'),
            onPressed: _processing
                ? null
                : () => context.push<void>('/documents/new'),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Ajouter / analyser un document'),
          ),
        ],
      ),
    );
  }

  Widget _scopeCard() {
    final scope = _scope;
    final scheme = Theme.of(context).colorScheme;
    final attention =
        scope.level == LegalScopeLevel.escalationRequired ||
        scope.level == LegalScopeLevel.dossierOnly;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: attention ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            attention ? Icons.warning_amber_rounded : Icons.fact_check_outlined,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scope.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(scope.message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultView(LegalAnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Votre dossier',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _sectionCard(title: 'Résumé', child: Text(result.caseSummary)),
        if (result.confirmedFacts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _bulletCard('Faits confirmés', result.confirmedFacts),
        ],
        if (result.documentPointsToVerify.isNotEmpty) ...[
          const SizedBox(height: 12),
          _bulletCard(
            'Informations de documents à vérifier',
            result.documentPointsToVerify,
          ),
        ],
        if (result.missingInformation.isNotEmpty) ...[
          const SizedBox(height: 12),
          _bulletCard(
            'Ce qui manque à votre dossier',
            result.missingInformation,
          ),
        ],
        if (result.analysisPoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Ce que les sources permettent d’expliquer',
            child: Column(
              children: result.analysisPoints
                  .map(
                    (point) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(point.title),
                      subtitle: Text(point.explanation),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
        if (result.officialSources.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Sources officielles consultées',
            child: Column(
              children: result.officialSources
                  .map(
                    (source) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: Text(source.title),
                      subtitle: Text(
                        [
                          source.reference,
                          source.relevance,
                        ].where((value) => value.trim().isNotEmpty).join('\n'),
                      ),
                      onTap: () async {
                        final uri = Uri.tryParse(source.url);
                        if (uri == null) return;
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
        if (result.nextSteps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Prochaine démarche utile',
            child: Column(
              children: result.nextSteps
                  .map(
                    (step) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${step.order}')),
                      title: Text(step.title),
                      subtitle: Text(step.description),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
        if (result.factualDraft.available) ...[
          const SizedBox(height: 12),
          _sectionCard(
            title: result.factualDraft.title.isEmpty
                ? 'Brouillon factuel'
                : result.factualDraft.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(result.factualDraft.body),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: result.factualDraft.body),
                    );
                    if (mounted) _showMessage('Brouillon copié.');
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copier le brouillon'),
                ),
              ],
            ),
          ),
        ],
        if (result.questionsToAnswer.isNotEmpty && _caseId != null) ...[
          const SizedBox(height: 12),
          _bulletCard('Questions à compléter', result.questionsToAnswer),
          const SizedBox(height: 10),
          TextField(
            controller: _additionalController,
            minLines: 2,
            maxLines: 5,
            maxLength: 1200,
            decoration: const InputDecoration(
              labelText: 'Ajouter une précision au dossier',
              alignLabelWithHint: true,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _processing ? null : _reanalyze,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Ajouter et réanalyser'),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: result.toClipboardText()),
            );
            if (mounted) _showMessage('Résumé du dossier copié.');
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copier le résumé du dossier'),
        ),
        if (_caseId != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('legal-support-delete-case'),
            onPressed: _processing ? null : _deleteCurrentCase,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Supprimer ce dossier'),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          result.disclaimer.isEmpty
              ? 'Cette analyse automatisée aide à préparer vos démarches et ne remplace pas un professionnel du droit.'
              : result.disclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bulletCard(String title, List<String> items) {
    return _sectionCard(
      title: title,
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message),
    );
  }
}
