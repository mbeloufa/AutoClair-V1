import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'document_analysis_result.dart';
import 'document_carnet_sync_result.dart';
import 'document_analysis_service.dart';

class AnalysisResultPage extends StatefulWidget {
  const AnalysisResultPage({required this.documentId, super.key});

  final String documentId;

  @override
  State<AnalysisResultPage> createState() => _AnalysisResultPageState();
}

class _AnalysisResultPageState extends State<AnalysisResultPage> {
  final _service = DocumentAnalysisService();

  DocumentAnalysisResult? _result;
  DocumentCarnetSyncResult? _carnetSync;
  String? _errorMessage;
  String? _carnetSyncError;
  bool _loading = true;
  bool _syncingCarnet = false;
  bool _confirmingCarnetEvent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _carnetSyncError = null;
    });

    try {
      final result = await _service.fetchAnalysis(widget.documentId);
      if (!mounted) return;

      setState(() {
        _result = result;
        _loading = false;
      });

      await _syncCarnet();
    } on DocumentAnalysisException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncCarnet() async {
    if (_syncingCarnet) return;

    setState(() {
      _syncingCarnet = true;
      _carnetSyncError = null;
    });

    try {
      final sync = await _service.syncDocumentToCarnet(widget.documentId);
      if (mounted) {
        setState(() => _carnetSync = sync);
      }
    } on DocumentAnalysisException catch (error) {
      if (mounted) {
        setState(() => _carnetSyncError = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _syncingCarnet = false);
      }
    }
  }

  Future<void> _confirmCarnetEvent() async {
    if (_confirmingCarnetEvent) return;

    setState(() {
      _confirmingCarnetEvent = true;
      _carnetSyncError = null;
    });

    try {
      final confirmed = await _service.confirmDocumentCarnetEvent(
        widget.documentId,
      );

      if (!mounted) return;

      setState(() => _carnetSync = confirmed);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Événement confirmé dans le carnet.')),
      );
    } on DocumentAnalysisException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _confirmingCarnetEvent = false);
      }
    }
  }

  void _openVehicleCarnet(DocumentCarnetSyncResult sync) {
    final vehicleId = sync.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final section = sync.wasAutomaticallyAdded ? 'timeline' : 'overview';
    context.push('/vehicles/$vehicleId/care?section=$section');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Résultat de l'analyse")),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: AppColors.primary,
              ),
              const SizedBox(height: 18),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final result = _result!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        _SummaryCard(result: result),
        const SizedBox(height: 18),
        _CarnetSyncCard(
          sync: _carnetSync,
          errorMessage: _carnetSyncError,
          loading: _syncingCarnet,
          confirming: _confirmingCarnetEvent,
          onRetry: _syncCarnet,
          onConfirm:
              _carnetSync?.wasAutomaticallyAdded == true &&
                  _carnetSync?.userConfirmed == false
              ? _confirmCarnetEvent
              : null,
          onOpenCarnet: _carnetSync?.canOpenCarnet == true
              ? () => _openVehicleCarnet(_carnetSync!)
              : null,
        ),
        const SizedBox(height: 18),
        _DocumentInformationSection(result: result),
        const SizedBox(height: 18),
        _AmountsSection(result: result),
        const SizedBox(height: 18),
        _LineItemsSection(result: result),
        const SizedBox(height: 18),
        _ObservationsSection(result: result),
        const SizedBox(height: 18),
        _StringListSection(
          title: 'Questions à poser au garage',
          icon: Icons.help_outline,
          accentColor: AppColors.success,
          accentBackground: AppColors.successSoft,
          values: result.stringListAt('questions_to_ask'),
          emptyMessage: 'Aucune question particulière proposée.',
        ),
        const SizedBox(height: 18),
        _StringListSection(
          title: 'Points à vérifier',
          icon: Icons.warning_amber_outlined,
          accentColor: AppColors.warning,
          accentBackground: AppColors.warningSoft,
          values: result.stringListAt('uncertainties'),
          emptyMessage: 'Aucune incertitude particulière signalée.',
        ),
        const SizedBox(height: 18),
        _DisclaimerCard(
          text:
              result.stringAt('disclaimer') ??
              "Cette analyse ne remplace pas un diagnostic mécanique "
                  'ou une expertise professionnelle.',
        ),
        const SizedBox(height: 18),
        const _ResultNavigation(),
      ],
    );
  }
}

class _CarnetSyncCard extends StatelessWidget {
  const _CarnetSyncCard({
    required this.sync,
    required this.errorMessage,
    required this.loading,
    required this.confirming,
    required this.onRetry,
    required this.onConfirm,
    required this.onOpenCarnet,
  });

  final DocumentCarnetSyncResult? sync;
  final String? errorMessage;
  final bool loading;
  final bool confirming;
  final VoidCallback onRetry;
  final VoidCallback? onConfirm;
  final VoidCallback? onOpenCarnet;

  @override
  Widget build(BuildContext context) {
    if (loading && sync == null) {
      return const _CarnetSyncContainer(
        icon: Icons.sync_rounded,
        color: AppColors.info,
        background: AppColors.infoSoft,
        title: 'Mise à jour du carnet',
        message:
            'AutoClair vérifie si ce document peut créer un événement fiable.',
        trailing: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (errorMessage != null) {
      return _CarnetSyncContainer(
        icon: Icons.sync_problem_rounded,
        color: AppColors.warning,
        background: AppColors.warningSoft,
        title: 'Carnet non mis à jour',
        message:
            '$errorMessage Le résultat de l’analyse reste disponible et '
            'aucune donnée incertaine n’a été ajoutée.',
        action: OutlinedButton.icon(
          onPressed: loading ? null : onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      );
    }

    final value = sync;
    if (value == null) {
      return _CarnetSyncContainer(
        icon: Icons.shield_outlined,
        color: AppColors.info,
        background: AppColors.infoSoft,
        title: 'Protection du carnet active',
        message:
            'L’ajout automatique est limité aux documents suffisamment '
            'fiables et clairement rattachés au véhicule.',
        action: OutlinedButton.icon(
          onPressed: loading ? null : onRetry,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Vérifier maintenant'),
        ),
      );
    }

    if (value.wasAutomaticallyAdded) {
      return _CarnetSyncContainer(
        icon: value.userConfirmed
            ? Icons.library_add_check_rounded
            : Icons.pending_actions_rounded,
        color: value.userConfirmed ? AppColors.success : AppColors.warning,
        background: value.userConfirmed
            ? AppColors.successSoft
            : AppColors.warningSoft,
        title: value.userConfirmed
            ? 'Événement confirmé dans le carnet'
            : value.status == 'AUTO_CREATED'
            ? 'Événement ajouté — à vérifier'
            : 'Événement déjà présent — à vérifier',
        message:
            '${value.eventTitle ?? value.message}\n'
            '${value.matchLabel}'
            '${value.matchScore == null ? '' : ' • confiance de rapprochement ${(value.matchScore! * 100).round()} %'}'
            '${value.suggestionCount > 0 ? '\n${value.suggestionCount} autre(s) information(s) restent à vérifier.' : ''}',
        action: value.userConfirmed
            ? FilledButton.tonalIcon(
                onPressed: onOpenCarnet,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Voir l’événement confirmé'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: confirming ? null : onConfirm,
                    icon: confirming
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      confirming ? 'Confirmation…' : 'Confirmer cet événement',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onOpenCarnet,
                    icon: const Icon(Icons.timeline_rounded),
                    label: const Text('Voir avant de confirmer'),
                  ),
                ],
              ),
      );
    }

    if (value.needsReview) {
      return _CarnetSyncContainer(
        icon: Icons.fact_check_outlined,
        color: AppColors.warning,
        background: AppColors.warningSoft,
        title: 'Vérification nécessaire',
        message:
            '${value.message}'
            '${value.suggestionCount > 0 ? '\n${value.suggestionCount} proposition(s) sont prêtes dans le carnet.' : ''}'
            '${value.suggestionPreparationFailed ? '\nLa préparation automatique pourra être relancée depuis le carnet.' : ''}',
        action: FilledButton.tonalIcon(
          onPressed: onOpenCarnet,
          icon: const Icon(Icons.rule_rounded),
          label: const Text('Vérifier dans le carnet'),
        ),
      );
    }

    return _CarnetSyncContainer(
      icon: Icons.info_outline_rounded,
      color: AppColors.info,
      background: AppColors.infoSoft,
      title: 'Aucun événement ajouté automatiquement',
      message: value.message,
      action: onOpenCarnet == null
          ? null
          : OutlinedButton.icon(
              onPressed: onOpenCarnet,
              icon: const Icon(Icons.directions_car_outlined),
              label: const Text('Ouvrir le carnet'),
            ),
    );
  }
}

class _CarnetSyncContainer extends StatelessWidget {
  const _CarnetSyncContainer({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
    this.action,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;
  final Widget? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 9),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[const SizedBox(height: 14), action!],
          const SizedBox(height: 10),
          Text(
            'Sécurité : aucun ajout automatique en cas de conflit VIN ou '
            'immatriculation, de devis, de date incertaine ou de confiance '
            'insuffisante.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Synthèse AutoClair',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.summary,
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WhiteChip(label: result.detectedTypeLabel),
              _WhiteChip(label: 'Confiance ${result.confidenceLabel}'),
              _WhiteChip(label: 'Lisibilité ${result.readabilityLabel}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteChip extends StatelessWidget {
  const _WhiteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DocumentInformationSection extends StatelessWidget {
  const _DocumentInformationSection({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final parties = result.objectAt('parties');
    final vehicle = result.objectAt('vehicle');
    final dates = result.objectAt('dates');

    final rows = <MapEntry<String, String?>>[
      MapEntry('Garage', _text(parties['garage_name'])),
      MapEntry('Adresse', _text(parties['garage_address'])),
      MapEntry('Véhicule', _vehicleLabel(vehicle)),
      MapEntry('Immatriculation', _text(vehicle['registration_number'])),
      MapEntry('VIN', _text(vehicle['vin'])),
      MapEntry('Kilométrage', _numberLabel(vehicle['mileage'], suffix: ' km')),
      MapEntry('Date du document', _text(dates['document_date'])),
      MapEntry('Fin de validité', _text(dates['validity_end_date'])),
    ].where((row) => row.value != null).toList();

    return _SectionCard(
      title: 'Informations relevées',
      icon: Icons.description_outlined,
      accentColor: AppColors.info,
      accentBackground: AppColors.infoSoft,
      child: rows.isEmpty
          ? const Text("Aucune information certaine n'a été relevée.")
          : Column(
              children: rows
                  .map((row) => _KeyValueRow(label: row.key, value: row.value!))
                  .toList(growable: false),
            ),
    );
  }

  static String? _vehicleLabel(Map<String, dynamic> vehicle) {
    final make = _text(vehicle['make']);
    final model = _text(vehicle['model']);

    final parts = [make, model].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class _AmountsSection extends StatelessWidget {
  const _AmountsSection({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final amounts = result.objectAt('amounts');
    final currency = _text(amounts['currency']) ?? 'EUR';

    final rows = <MapEntry<String, String?>>[
      MapEntry('Total HT', _money(amounts['subtotal_excluding_tax'], currency)),
      MapEntry('TVA', _money(amounts['tax_amount'], currency)),
      MapEntry('Total TTC', _money(amounts['total_including_tax'], currency)),
    ].where((row) => row.value != null).toList();

    return _SectionCard(
      title: 'Montants',
      icon: Icons.euro_outlined,
      accentColor: AppColors.success,
      accentBackground: AppColors.successSoft,
      child: rows.isEmpty
          ? const Text("Aucun montant suffisamment lisible n'a été relevé.")
          : Column(
              children: rows
                  .map(
                    (row) => _KeyValueRow(
                      label: row.key,
                      value: row.value!,
                      emphasize: row.key == 'Total TTC',
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _LineItemsSection extends StatelessWidget {
  const _LineItemsSection({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final items = result.objectListAt('line_items');

    return _SectionCard(
      title: 'Prestations et pièces',
      icon: Icons.build_outlined,
      child: items.isEmpty
          ? const Text("Aucune ligne exploitable n'a été identifiée.")
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 28),
                  _LineItem(item: items[index]),
                ],
              ],
            ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final description = _text(item['description']) ?? 'Ligne non nommée';
    final explanation = _text(item['explanation']);
    final total = _money(item['total_excluding_tax'], 'EUR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                description,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (total != null) ...[
              const SizedBox(width: 12),
              Text(
                '$total HT',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Text(
          _necessityLabel(item['necessity_assessment']?.toString()),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (explanation != null) ...[
          const SizedBox(height: 7),
          Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  static String _necessityLabel(String? value) {
    return switch (value) {
      'explicitly_required' => 'Présentée comme nécessaire',
      'recommended' => 'Recommandée',
      'optional' => 'Optionnelle',
      _ => 'Nécessité à clarifier',
    };
  }
}

class _ObservationsSection extends StatelessWidget {
  const _ObservationsSection({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final observations = result.objectListAt('observations');

    return _SectionCard(
      title: 'Points à retenir',
      icon: Icons.fact_check_outlined,
      accentColor: AppColors.warning,
      accentBackground: AppColors.warningSoft,
      child: observations.isEmpty
          ? const Text('Aucun point particulier signalé.')
          : Column(
              children: [
                for (var index = 0; index < observations.length; index++) ...[
                  if (index > 0) const Divider(height: 28),
                  _Observation(item: observations[index]),
                ],
              ],
            ),
    );
  }
}

class _Observation extends StatelessWidget {
  const _Observation({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = _text(item['title']) ?? 'Observation';
    final explanation = _text(item['explanation']) ?? '';
    final level = item['level']?.toString();
    final (label, icon, color, background) = switch (level) {
      'important' => (
        'Alerte',
        Icons.priority_high_rounded,
        AppColors.error,
        AppColors.errorSoft,
      ),
      'attention' => (
        'À surveiller',
        Icons.warning_amber_outlined,
        AppColors.warning,
        AppColors.warningSoft,
      ),
      _ => (
        'Information',
        Icons.info_outline,
        AppColors.info,
        AppColors.infoSoft,
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.45,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (explanation.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(explanation),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StringListSection extends StatelessWidget {
  const _StringListSection({
    required this.title,
    required this.icon,
    required this.values,
    required this.emptyMessage,
    this.accentColor = AppColors.primary,
    this.accentBackground = AppColors.softPrimary,
  });

  final String title;
  final IconData icon;
  final List<String> values;
  final String emptyMessage;
  final Color accentColor;
  final Color accentBackground;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      accentColor: accentColor,
      accentBackground: accentBackground,
      child: values.isEmpty
          ? Text(emptyMessage)
          : Column(
              children: values
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(value)),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor = AppColors.primary,
    this.accentBackground = AppColors.softPrimary,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;
  final Color accentBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
      fontSize: emphasize ? 17 : null,
      color: emphasize ? AppColors.primary : AppColors.text,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _ResultNavigation extends StatelessWidget {
  const _ResultNavigation();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/history'),
          icon: const Icon(Icons.history_outlined),
          label: const Text('Retour à l’historique'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Retour à l’accueil'),
        ),
      ],
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _numberLabel(dynamic value, {String suffix = ''}) {
  if (value == null) {
    return null;
  }

  final number = value is num ? value : num.tryParse(value.toString());

  if (number == null) {
    return null;
  }

  final display = number % 1 == 0
      ? number.toInt().toString()
      : number.toStringAsFixed(2);

  return '$display$suffix';
}

String? _money(dynamic value, String currency) {
  if (value == null) {
    return null;
  }

  final number = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());

  if (number == null) {
    return null;
  }

  final symbol = currency == 'EUR' ? '€' : currency;
  return '${number.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
}
