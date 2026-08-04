import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_360_models.dart';
import 'vehicle_360_service.dart';
import 'vehicle_value_chart.dart';

enum Vehicle360Section { report, sale, sources }

class Vehicle360Page extends StatefulWidget {
  const Vehicle360Page({
    required this.vehicleId,
    this.initialSection,
    super.key,
  });

  final String vehicleId;
  final String? initialSection;

  @override
  State<Vehicle360Page> createState() => _Vehicle360PageState();
}

class _Vehicle360PageState extends State<Vehicle360Page> {
  final _service = Vehicle360Service();

  Vehicle360Precheck? _precheck;
  Vehicle360Report? _report;
  late Vehicle360Section _section;
  bool _loading = true;
  bool _generating = false;
  bool _refreshingValuation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection == 'sale'
        ? Vehicle360Section.sale
        : Vehicle360Section.report;
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final precheck = await _service.precheck(widget.vehicleId);
      if (!mounted) return;
      setState(() {
        _precheck = precheck;
        _report = precheck.latestReport;
      });
    } on Vehicle360Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_generating) return;

    if (_report != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Actualiser le bilan ?'),
          content: const Text(
            'AutoClair vérifiera les nouvelles informations du véhicule. '
            "Si rien n'a changé, le bilan existant sera réutilisé sans nouvel appel.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    try {
      final report = await _service.generate(widget.vehicleId);
      if (!mounted) return;
      setState(() {
        _report = report;
        _section = Vehicle360Section.report;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le bilan AutoClair 360 est prêt.')),
      );
    } on Vehicle360Exception catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _refreshValuation() async {
    if (_refreshingValuation) return;
    setState(() => _refreshingValuation = true);
    try {
      await _service.refreshValuation(widget.vehicleId, forceRefresh: true);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cote a été actualisée.')),
        );
      }
    } on Vehicle360Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _refreshingValuation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan AutoClair 360'),
        actions: [
          IconButton(
            onPressed: _loading || _generating ? null : _load,
            tooltip: 'Actualiser les informations',
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _precheck == null) {
      return const _LoadingView(
        title: 'Préparation du bilan',
        message: 'AutoClair rassemble les informations du véhicule.',
      );
    }

    if (_generating) {
      return const _LoadingView(
        title: 'Analyse professionnelle en cours',
        message:
            'AutoClair vérifie le carnet, les échéances, les documents, '
            "l’usage et les données de vente. Cette étape peut durer une minute.",
      );
    }

    if (_errorMessage != null && _precheck == null) {
      return _ErrorView(message: _errorMessage!, onRetry: _load);
    }

    final report = _report;
    final precheck = _precheck!;
    if (report == null) {
      return _PrecheckView(
        precheck: precheck,
        errorMessage: _errorMessage,
        onGenerate: _generate,
      );
    }

    return _ReportView(
      report: report,
      selectedSection: _section,
      refreshingValuation: _refreshingValuation,
      onSectionChanged: (value) => setState(() => _section = value),
      onGenerate: _generate,
      onRefreshValuation: _refreshValuation,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.softPrimary,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const SizedBox(
              width: 220,
              child: LinearProgressIndicator(minHeight: 7),
            ),
            const SizedBox(height: 14),
            Text(
              'Ne fermez pas cette page.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrecheckView extends StatelessWidget {
  const _PrecheckView({
    required this.precheck,
    required this.onGenerate,
    this.errorMessage,
  });

  final Vehicle360Precheck precheck;
  final VoidCallback onGenerate;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final quality = precheck.dataQuality;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        const _PremiumHero(),
        const SizedBox(height: 18),
        _DataQualityCard(quality: quality),
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          _MessageCard(
            icon: Icons.error_outline,
            title: 'Le bilan n’a pas pu être lancé',
            message: errorMessage!,
            color: AppColors.error,
            background: AppColors.errorSoft,
          ),
        ],
        const SizedBox(height: 18),
        _AvailableDataCard(quality: quality),
        const SizedBox(height: 18),
        _MarketAvailabilityCard(marketData: precheck.marketData),
        const SizedBox(height: 18),
        const _WhatYouGetCard(),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: quality.canGenerate ? onGenerate : null,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(
            quality.canGenerate
                ? 'Lancer le bilan complet'
                : 'Compléter le véhicule avant le bilan',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Le bilan est généré avec l’aide de l’IA à partir des seules '
          'informations AutoClair. Il ne remplace pas un diagnostic mécanique.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero();

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
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 9),
              _WhitePill(label: 'Bilan complet'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Comprendre, anticiper et décider',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'AutoClair analyse le suivi réel du véhicule, les entretiens, '
            'les échéances, l’usage, le budget et la pertinence d’une vente.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataQualityCard extends StatelessWidget {
  const _DataQualityCard({required this.quality});

  final Vehicle360DataQuality quality;

  @override
  Widget build(BuildContext context) {
    final color = quality.score >= 75
        ? AppColors.success
        : quality.score >= 45
        ? AppColors.warning
        : AppColors.error;
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: quality.score / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.border,
                  color: color,
                ),
                Text(
                  '${quality.score} %',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quality.levelLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  quality.canGenerate
                      ? 'Les informations disponibles permettent un bilan utile.'
                      : 'Ajoutez les informations manquantes pour fiabiliser le bilan.',
                ),
                if (quality.missing.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'À compléter : ${quality.missing.join(', ')}.',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableDataCard extends StatelessWidget {
  const _AvailableDataCard({required this.quality});

  final Vehicle360DataQuality quality;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations prises en compte',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DataMetric(
                    width: width,
                    icon: Icons.timeline_outlined,
                    value: quality.eventCount,
                    label: 'entretiens et événements',
                  ),
                  _DataMetric(
                    width: width,
                    icon: Icons.description_outlined,
                    value: quality.documentCount,
                    label: 'documents et suggestions',
                  ),
                  _DataMetric(
                    width: width,
                    icon: Icons.euro_outlined,
                    value: quality.expenseCount,
                    label: 'dépenses enregistrées',
                  ),
                  _DataMetric(
                    width: width,
                    icon: Icons.campaign_outlined,
                    value: quality.recallCount,
                    label: 'rappels vérifiés',
                  ),
                ],
              );
            },
          ),
          if (quality.warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final warning in quality.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(warning)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DataMetric extends StatelessWidget {
  const _DataMetric({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });

  final double width;
  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(height: 8),
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MarketAvailabilityCard extends StatelessWidget {
  const _MarketAvailabilityCard({required this.marketData});

  final Vehicle360MarketData marketData;

  @override
  Widget build(BuildContext context) {
    if (marketData.available) {
      return _MessageCard(
        icon: Icons.show_chart_outlined,
        title: 'Cote professionnelle disponible',
        message:
            'La valeur actuelle et les projections seront intégrées au bilan.',
        color: AppColors.success,
        background: AppColors.successSoft,
      );
    }
    return const _MessageCard(
      icon: Icons.lock_clock_outlined,
      title: 'Cote professionnelle en attente',
      message:
          'Le bilan entretien et les conseils sont disponibles. La courbe de '
          'valeur sera ajoutée dès le branchement du fournisseur de cote.',
      color: AppColors.info,
      background: AppColors.infoSoft,
    );
  }
}

class _WhatYouGetCard extends StatelessWidget {
  const _WhatYouGetCard();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.fact_check_outlined, 'Bilan complet de l’entretien réel'),
      (Icons.calendar_month_outlined, 'Plan d’action sur douze mois'),
      (Icons.tips_and_updates_outlined, 'Conseils adaptés à l’usage'),
      (Icons.sell_outlined, 'Analyse de la pertinence d’une vente'),
      (Icons.question_answer_outlined, 'Questions à poser au professionnel'),
      (Icons.source_outlined, 'Conclusions reliées à leurs sources'),
    ];
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce que contient le bilan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  Icon(item.$1, color: AppColors.primary, size: 21),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.$2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.selectedSection,
    required this.refreshingValuation,
    required this.onSectionChanged,
    required this.onGenerate,
    required this.onRefreshValuation,
  });

  final Vehicle360Report report;
  final Vehicle360Section selectedSection;
  final bool refreshingValuation;
  final ValueChanged<Vehicle360Section> onSectionChanged;
  final VoidCallback onGenerate;
  final VoidCallback onRefreshValuation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
      children: [
        _ReportHero(report: report),
        const SizedBox(height: 16),
        SegmentedButton<Vehicle360Section>(
          segments: const [
            ButtonSegment(
              value: Vehicle360Section.report,
              label: Text('Bilan'),
              icon: Icon(Icons.fact_check_outlined),
            ),
            ButtonSegment(
              value: Vehicle360Section.sale,
              label: Text('Vente'),
              icon: Icon(Icons.sell_outlined),
            ),
            ButtonSegment(
              value: Vehicle360Section.sources,
              label: Text('Sources'),
              icon: Icon(Icons.source_outlined),
            ),
          ],
          selected: {selectedSection},
          showSelectedIcon: false,
          onSelectionChanged: (value) => onSectionChanged(value.first),
        ),
        const SizedBox(height: 18),
        switch (selectedSection) {
          Vehicle360Section.report => _ReportSection(report: report),
          Vehicle360Section.sale => _SaleSection(
            report: report,
            refreshingValuation: refreshingValuation,
            onRefreshValuation: onRefreshValuation,
          ),
          Vehicle360Section.sources => _SourcesSection(report: report),
        },
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Vérifier les nouvelles informations'),
        ),
      ],
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report});

  final Vehicle360Report report;

  @override
  Widget build(BuildContext context) {
    final style = _ReportStatusStyle.from(
      report.executiveSummary.overallStatus,
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 9),
              _WhitePill(label: 'Bilan du ${report.generatedLabel}'),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            report.executiveSummary.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            report.executiveSummary.summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon, color: style.foreground, size: 18),
                const SizedBox(width: 7),
                Text(
                  report.executiveSummary.statusLabel,
                  style: TextStyle(
                    color: style.foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.report});

  final Vehicle360Report report;

  @override
  Widget build(BuildContext context) {
    final maintenance = report.maintenance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReportMetrics(report: report),
        if (maintenance.urgentFindings.isNotEmpty) ...[
          const SizedBox(height: 18),
          _FindingSection(
            title: 'À traiter rapidement',
            subtitle: 'Points prioritaires identifiés dans le dossier',
            findings: maintenance.urgentFindings,
            color: AppColors.error,
            background: AppColors.errorSoft,
            icon: Icons.priority_high,
          ),
        ],
        if (maintenance.attentionFindings.isNotEmpty) ...[
          const SizedBox(height: 18),
          _FindingSection(
            title: 'À surveiller',
            subtitle: 'Vérifications utiles lors du prochain passage au garage',
            findings: maintenance.attentionFindings,
            color: AppColors.warning,
            background: AppColors.warningSoft,
            icon: Icons.visibility_outlined,
          ),
        ],
        if (maintenance.next12MonthActions.isNotEmpty) ...[
          const SizedBox(height: 18),
          _FindingSection(
            title: 'Plan d’action sur douze mois',
            subtitle: 'Les prochaines étapes, classées sans dramatiser',
            findings: maintenance.next12MonthActions,
            color: AppColors.info,
            background: AppColors.infoSoft,
            icon: Icons.calendar_month_outlined,
          ),
        ],
        if (maintenance.positiveFindings.isNotEmpty) ...[
          const SizedBox(height: 18),
          _FindingSection(
            title: 'Ce qui est bien suivi',
            subtitle: 'Les points positifs à conserver et à valoriser',
            findings: maintenance.positiveFindings,
            color: AppColors.success,
            background: AppColors.successSoft,
            icon: Icons.verified_outlined,
          ),
        ],
        if (report.usageAdvice.isNotEmpty) ...[
          const SizedBox(height: 18),
          _AdviceSection(
            title: 'Conseils personnalisés',
            subtitle:
                'Adaptés au véhicule et aux informations d’usage disponibles',
            advice: report.usageAdvice,
            color: AppColors.primary,
            background: AppColors.softPrimary,
            icon: Icons.tips_and_updates_outlined,
          ),
        ],
        if (report.questionsForProfessional.isNotEmpty) ...[
          const SizedBox(height: 18),
          _StringSection(
            title: 'Questions à poser au professionnel',
            values: report.questionsForProfessional,
            icon: Icons.question_answer_outlined,
          ),
        ],
        if (report.limitations.isNotEmpty) ...[
          const SizedBox(height: 18),
          _StringSection(
            title: 'Limites et informations manquantes',
            values: report.limitations,
            icon: Icons.info_outline,
            color: AppColors.warning,
          ),
        ],
        const SizedBox(height: 18),
        const _DisclaimerCard(),
      ],
    );
  }
}

class _ReportMetrics extends StatelessWidget {
  const _ReportMetrics({required this.report});

  final Vehicle360Report report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Qualité du dossier',
              value: '${report.dataQuality.score} %',
              icon: Icons.folder_copy_outlined,
            ),
            _MetricCard(
              width: width,
              label: 'Actions relevées',
              value: '${report.actionCount}',
              icon: Icons.task_alt_outlined,
            ),
            _MetricCard(
              width: width,
              label: 'Sources utilisées',
              value: '${report.sources.length}',
              icon: Icons.source_outlined,
            ),
            _MetricCard(
              width: width,
              label: 'Confiance',
              value: report.executiveSummary.confidence == 'high'
                  ? 'Élevée'
                  : report.executiveSummary.confidence == 'medium'
                  ? 'Moyenne'
                  : 'Limitée',
              icon: Icons.verified_user_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FindingSection extends StatelessWidget {
  const _FindingSection({
    required this.title,
    required this.subtitle,
    required this.findings,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Vehicle360Finding> findings;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: title, subtitle: subtitle),
        const SizedBox(height: 10),
        for (final finding in findings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FindingCard(
              finding: finding,
              color: color,
              background: background,
              icon: icon,
            ),
          ),
      ],
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({
    required this.finding,
    required this.color,
    required this.background,
    required this.icon,
  });

  final Vehicle360Finding finding;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finding.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${finding.priorityLabel} • Confiance ${finding.confidenceLabel}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (finding.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(finding.explanation),
          ],
          if (finding.action.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                finding.action,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdviceSection extends StatelessWidget {
  const _AdviceSection({
    required this.title,
    required this.subtitle,
    required this.advice,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Vehicle360Advice> advice;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: title, subtitle: subtitle),
        const SizedBox(height: 10),
        for (final item in advice)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AdviceCard(
              advice: item,
              color: color,
              background: background,
              icon: icon,
            ),
          ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.advice,
    required this.color,
    required this.background,
    required this.icon,
  });

  final Vehicle360Advice advice;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (advice.explanation.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(advice.explanation),
                ],
                if (advice.action.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    advice.action,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleSection extends StatelessWidget {
  const _SaleSection({
    required this.report,
    required this.refreshingValuation,
    required this.onRefreshValuation,
  });

  final Vehicle360Report report;
  final bool refreshingValuation;
  final VoidCallback onRefreshValuation;

  @override
  Widget build(BuildContext context) {
    final market = report.marketData;
    final sale = report.saleAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SaleRecommendationCard(sale: sale),
        const SizedBox(height: 18),
        _SectionHeading(
          title: 'Valeur du véhicule',
          subtitle: market.available
              ? market.freshnessLabel
              : 'Aucune cote contractuelle disponible actuellement',
          actionLabel: 'Actualiser',
          onAction: refreshingValuation ? null : onRefreshValuation,
        ),
        const SizedBox(height: 10),
        if (market.available)
          _MarketValueCard(market: market)
        else
          const _MessageCard(
            icon: Icons.query_stats_outlined,
            title: 'Courbe de valeur en attente',
            message:
                'AutoClair n’affiche aucun prix approximatif. La valeur et la '
                'projection seront activées uniquement avec une source professionnelle.',
            color: AppColors.info,
            background: AppColors.infoSoft,
          ),
        if (market.available) ...[
          const SizedBox(height: 18),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Évolution et projection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Historique réel et projection clairement séparés',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                VehicleValueChart(marketData: market),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SectionHeading(
          title: 'Comparer les scénarios',
          subtitle: 'Les montants inconnus restent volontairement non chiffrés',
        ),
        const SizedBox(height: 10),
        if (report.scenarios.isEmpty)
          const _MessageCard(
            icon: Icons.compare_arrows_outlined,
            title: 'Scénarios non chiffrés',
            message:
                'Ils apparaîtront dès qu’une cote de marché exploitable sera disponible.',
            color: AppColors.info,
            background: AppColors.infoSoft,
          )
        else
          for (final scenario in report.scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ScenarioCard(scenario: scenario),
            ),
        if (sale.preparationActions.isNotEmpty) ...[
          const SizedBox(height: 18),
          _AdviceSection(
            title: 'Préparer la vente',
            subtitle:
                'Actions utiles avant de publier une annonce ou demander une reprise',
            advice: sale.preparationActions,
            color: AppColors.primary,
            background: AppColors.softPrimary,
            icon: Icons.checklist_outlined,
          ),
        ],
        if (sale.negotiationPoints.isNotEmpty) ...[
          const SizedBox(height: 18),
          _AdviceSection(
            title: 'Points de négociation',
            subtitle: 'Éléments à valoriser ou à clarifier avec l’acheteur',
            advice: sale.negotiationPoints,
            color: AppColors.success,
            background: AppColors.successSoft,
            icon: Icons.handshake_outlined,
          ),
        ],
        const SizedBox(height: 18),
        _MessageCard(
          icon: Icons.info_outline,
          title: 'Une aide à la décision, pas un ordre de vendre',
          message: market.disclaimer,
          color: AppColors.info,
          background: AppColors.infoSoft,
        ),
      ],
    );
  }
}

class _SaleRecommendationCard extends StatelessWidget {
  const _SaleRecommendationCard({required this.sale});

  final Vehicle360SaleAnalysis sale;

  @override
  Widget build(BuildContext context) {
    final timing = sale.timing;
    final style = _SaleTimingStyle.from(timing.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: style.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommandation AutoClair',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timing.statusLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: style.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(sale.summary),
          if (timing.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final reason in timing.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: style.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MarketValueCard extends StatelessWidget {
  const _MarketValueCard({required this.market});

  final Vehicle360MarketData market;

  @override
  Widget build(BuildContext context) {
    final privateValue = market.privateSale;
    final tradeValue = market.tradeIn;
    final depreciation = market.projectedDepreciationAmount;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (privateValue != null)
            _ValueBlock(
              label: 'Vente entre particuliers',
              valuation: privateValue,
              icon: Icons.person_outline,
            ),
          if (privateValue != null && tradeValue != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
          if (tradeValue != null)
            _ValueBlock(
              label: 'Reprise professionnelle',
              valuation: tradeValue,
              icon: Icons.storefront_outlined,
            ),
          if (depreciation != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            Row(
              children: [
                const Icon(Icons.trending_down, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Décote centrale projetée sur douze mois',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  _formatEuro(depreciation),
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({
    required this.label,
    required this.valuation,
    required this.icon,
  });

  final String label;
  final VehicleMarketValuation valuation;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final range = valuation.valueLow != null && valuation.valueHigh != null
        ? '${_formatEuro(valuation.valueLow!)} à ${_formatEuro(valuation.valueHigh!)}'
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.softPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                _formatEuro(valuation.valueMid),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (range != null) ...[
                const SizedBox(height: 3),
                Text('Fourchette probable : $range'),
              ],
              const SizedBox(height: 5),
              Text(
                '${valuation.provider} • estimation non garantie',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final VehicleSaleScenario scenario;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scenario.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (scenario.expectedSaleValue != null)
                Text(
                  _formatEuro(scenario.expectedSaleValue!),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(scenario.explanation),
          if (scenario.estimatedDelayDays != null) ...[
            const SizedBox(height: 9),
            Text(
              'Délai indicatif : ${scenario.estimatedDelayDays} jour(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (scenario.requiredCosts == null ||
              scenario.holdingCosts == null ||
              scenario.expectedNetValue == null) ...[
            const SizedBox(height: 9),
            Text(
              'Les coûts inconnus ne sont pas estimés artificiellement.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.report});

  final Vehicle360Report report;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Vehicle360Source>>{};
    for (final source in report.sources) {
      grouped.putIfAbsent(source.typeLabel, () => []).add(source);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MessageCard(
          icon: Icons.verified_user_outlined,
          title: 'Un bilan traçable',
          message:
              'Chaque conclusion factuelle est reliée à une information présente '
              'dans le dossier. Les références inexistantes sont rejetées par le serveur.',
          color: AppColors.success,
          background: AppColors.successSoft,
        ),
        const SizedBox(height: 18),
        if (grouped.isEmpty)
          const _MessageCard(
            icon: Icons.source_outlined,
            title: 'Aucune source affichable',
            message: 'Le bilan ne contient pas encore de source détaillée.',
            color: AppColors.info,
            background: AppColors.infoSoft,
          )
        else
          for (final entry in grouped.entries) ...[
            _SectionHeading(
              title: entry.key,
              subtitle: '${entry.value.length} élément(s) utilisé(s)',
            ),
            const SizedBox(height: 9),
            for (final source in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _SourceCard(source: source),
              ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 8),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Méthode AutoClair',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const _MethodLine(
                number: '1',
                text: 'Les données du véhicule sont rassemblées et contrôlées.',
              ),
              const _MethodLine(
                number: '2',
                text: 'Les calculs et scénarios sont produits sans IA.',
              ),
              const _MethodLine(
                number: '3',
                text: 'L’IA explique et personnalise sans inventer de valeur.',
              ),
              const _MethodLine(
                number: '4',
                text: 'Le serveur vérifie les sources avant l’affichage.',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final Vehicle360Source source;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${source.typeLabel} • Confiance ${source.confidenceLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodLine extends StatelessWidget {
  const _MethodLine({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  final String number;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}

class _StringSection extends StatelessWidget {
  const _StringSection({
    required this.title,
    required this.values,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String title;
  final List<String> values;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < values.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(values[index])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.shield_outlined,
      title: 'À retenir',
      message:
          'Ce bilan est assisté par IA. Il ne remplace pas un diagnostic '
          'mécanique, une expertise automobile ou un prix de vente garanti.',
      color: AppColors.textMuted,
      background: AppColors.background,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 5),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReportStatusStyle {
  const _ReportStatusStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _ReportStatusStyle.from(String status) => switch (status) {
    'good' => const _ReportStatusStyle(
      background: AppColors.successSoft,
      foreground: AppColors.success,
      icon: Icons.verified_outlined,
    ),
    'monitor' => const _ReportStatusStyle(
      background: AppColors.infoSoft,
      foreground: AppColors.info,
      icon: Icons.visibility_outlined,
    ),
    'plan' => const _ReportStatusStyle(
      background: AppColors.warningSoft,
      foreground: AppColors.warning,
      icon: Icons.event_note_outlined,
    ),
    'urgent' => const _ReportStatusStyle(
      background: AppColors.errorSoft,
      foreground: AppColors.error,
      icon: Icons.priority_high,
    ),
    _ => const _ReportStatusStyle(
      background: AppColors.infoSoft,
      foreground: AppColors.info,
      icon: Icons.info_outline,
    ),
  };
}

class _SaleTimingStyle {
  const _SaleTimingStyle({
    required this.background,
    required this.color,
    required this.icon,
  });

  final Color background;
  final Color color;
  final IconData icon;

  factory _SaleTimingStyle.from(String status) => switch (status) {
    'compare_now' => const _SaleTimingStyle(
      background: AppColors.warningSoft,
      color: AppColors.warning,
      icon: Icons.compare_arrows_outlined,
    ),
    'prepare_then_sell' => const _SaleTimingStyle(
      background: AppColors.softPrimary,
      color: AppColors.primary,
      icon: Icons.checklist_outlined,
    ),
    'monitor' => const _SaleTimingStyle(
      background: AppColors.successSoft,
      color: AppColors.success,
      icon: Icons.visibility_outlined,
    ),
    _ => const _SaleTimingStyle(
      background: AppColors.infoSoft,
      color: AppColors.info,
      icon: Icons.help_outline,
    ),
  };
}

String _formatEuro(double value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return '${buffer.toString()} €';
}
