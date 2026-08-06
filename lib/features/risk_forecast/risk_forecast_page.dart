import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'risk_forecast_calculator.dart';
import 'risk_forecast_models.dart';
import 'risk_forecast_service.dart';

class RiskForecastPage extends StatefulWidget {
  const RiskForecastPage({super.key});

  @override
  State<RiskForecastPage> createState() => _RiskForecastPageState();
}

class _RiskForecastPageState extends State<RiskForecastPage> {
  final RiskForecastService _service = RiskForecastService();
  final TextEditingController _currentMileageController =
      TextEditingController();
  final TextEditingController _annualMileageController =
      TextEditingController();
  final TextEditingController _vehicleAgeController = TextEditingController();
  final TextEditingController _monthsSinceServiceController =
      TextEditingController();
  final TextEditingController _kmSinceServiceController =
      TextEditingController();
  final TextEditingController _breakdownsController = TextEditingController();

  List<Vehicle> _vehicles = const [];
  List<RiskForecastSnapshot> _recentAssessments = const [];
  String? _selectedVehicleId;
  bool _shortTripsOften = false;
  bool _intensiveUse = false;
  bool _longImmobilization = false;
  bool _maintenancePlanned = false;
  bool _dashboardWarning = false;
  bool _brakingConcern = false;
  bool _tireConcern = false;
  bool _startingConcern = false;
  bool _engineCoolingConcern = false;
  RiskForecastAssessment? _assessment;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentMileageController.dispose();
    _annualMileageController.dispose();
    _vehicleAgeController.dispose();
    _monthsSinceServiceController.dispose();
    _kmSinceServiceController.dispose();
    _breakdownsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _service.loadVehicles();
      if (!mounted) return;
      final selected = vehicles.isEmpty ? null : vehicles.first.id;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selected;
      });
      if (selected != null) {
        await _loadVehicleData(selected);
      }
    } on RiskForecastException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicleData(String vehicleId) async {
    try {
      final results = await Future.wait([
        _service.loadProfile(vehicleId),
        _service.loadRecentAssessments(vehicleId),
      ]);
      if (!mounted || _selectedVehicleId != vehicleId) return;
      final profile = results[0] as RiskForecastProfile?;
      final recent = results[1] as List<RiskForecastSnapshot>;
      _applyProfile(profile ?? RiskForecastProfile.defaults(vehicleId));
      setState(() {
        _recentAssessments = recent;
        _assessment = null;
      });
    } on RiskForecastException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  void _applyProfile(RiskForecastProfile profile) {
    _currentMileageController.text = profile.currentMileage == 0
        ? ''
        : profile.currentMileage.toString();
    _annualMileageController.text = profile.annualMileage.toString();
    _vehicleAgeController.text = profile.vehicleAgeYears.toString();
    _monthsSinceServiceController.text = profile.monthsSinceService.toString();
    _kmSinceServiceController.text = profile.kmSinceService.toString();
    _breakdownsController.text = profile.repeatedBreakdowns12m.toString();
    _shortTripsOften = profile.shortTripsOften;
    _intensiveUse = profile.intensiveUse;
    _longImmobilization = profile.longImmobilization;
    _maintenancePlanned = profile.maintenancePlanned;
    _dashboardWarning = profile.dashboardWarning;
    _brakingConcern = profile.brakingConcern;
    _tireConcern = profile.tireConcern;
    _startingConcern = profile.startingConcern;
    _engineCoolingConcern = profile.engineCoolingConcern;
  }

  RiskForecastProfile _profile() {
    return RiskForecastProfile(
      vehicleId: _selectedVehicleId ?? '',
      currentMileage: _intFrom(_currentMileageController),
      annualMileage: _intFrom(_annualMileageController),
      vehicleAgeYears: _intFrom(_vehicleAgeController),
      monthsSinceService: _intFrom(_monthsSinceServiceController),
      kmSinceService: _intFrom(_kmSinceServiceController),
      shortTripsOften: _shortTripsOften,
      intensiveUse: _intensiveUse,
      longImmobilization: _longImmobilization,
      maintenancePlanned: _maintenancePlanned,
      dashboardWarning: _dashboardWarning,
      brakingConcern: _brakingConcern,
      tireConcern: _tireConcern,
      startingConcern: _startingConcern,
      engineCoolingConcern: _engineCoolingConcern,
      repeatedBreakdowns12m: _intFrom(_breakdownsController),
    );
  }

  int _intFrom(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return null;
  }

  Future<void> _analyze() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final assessment = RiskForecastCalculator.assess(profile);
      await _service.saveProfile(profile);
      await _service.saveAssessment(profile: profile, assessment: assessment);
      final recent = await _service.loadRecentAssessments(profile.vehicleId);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _recentAssessments = recent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyse préventive enregistrée.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on RiskForecastException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copySummary() async {
    final assessment = _assessment;
    final vehicle = _selectedVehicle;
    if (assessment == null || vehicle == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: assessment.buildShareSummary(vehicleLabel: vehicle.displayName),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé préventif copié.')));
  }

  void _changed(VoidCallback update) {
    setState(() {
      update();
      _assessment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Risques à anticiper')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ajoutez d’abord un véhicule pour lancer une analyse préventive.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              key: const ValueKey('risk-forecast-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _ForecastIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Véhicule et repères',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedVehicleId,
                        decoration: const InputDecoration(
                          labelText: 'Véhicule analysé',
                        ),
                        items: [
                          for (final vehicle in _vehicles)
                            DropdownMenuItem(
                              value: vehicle.id,
                              child: Text(vehicle.displayName),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() {
                            _selectedVehicleId = value;
                            _assessment = null;
                            _error = null;
                          });
                          await _loadVehicleData(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumns = constraints.maxWidth >= 560;
                          final fieldWidth = twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _NumberField(
                                width: fieldWidth,
                                controller: _currentMileageController,
                                label: 'Kilométrage actuel',
                                suffix: 'km',
                              ),
                              _NumberField(
                                width: fieldWidth,
                                controller: _annualMileageController,
                                label: 'Kilométrage annuel estimé',
                                suffix: 'km/an',
                              ),
                              _NumberField(
                                width: fieldWidth,
                                controller: _vehicleAgeController,
                                label: 'Âge du véhicule',
                                suffix: 'ans',
                              ),
                              _NumberField(
                                width: fieldWidth,
                                controller: _monthsSinceServiceController,
                                label: 'Depuis le dernier entretien',
                                suffix: 'mois',
                              ),
                              _NumberField(
                                width: fieldWidth,
                                controller: _kmSinceServiceController,
                                label: 'Distance depuis l’entretien',
                                suffix: 'km',
                              ),
                              _NumberField(
                                width: fieldWidth,
                                controller: _breakdownsController,
                                label: 'Pannes sur les 12 derniers mois',
                                suffix: 'panne(s)',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Usage et entretien',
                  child: Column(
                    children: [
                      _BooleanTile(
                        title: 'Trajets courts fréquents',
                        subtitle:
                            'Nombreux démarrages et trajets souvent inférieurs à 15 minutes.',
                        value: _shortTripsOften,
                        onChanged: (value) =>
                            _changed(() => _shortTripsOften = value),
                      ),
                      _BooleanTile(
                        title: 'Usage contraignant',
                        subtitle:
                            'Charge, remorquage, montagne ou circulation dense fréquente.',
                        value: _intensiveUse,
                        onChanged: (value) =>
                            _changed(() => _intensiveUse = value),
                      ),
                      _BooleanTile(
                        title: 'Immobilisations prolongées',
                        subtitle:
                            'Le véhicule reste régulièrement plusieurs semaines sans rouler.',
                        value: _longImmobilization,
                        onChanged: (value) =>
                            _changed(() => _longImmobilization = value),
                      ),
                      _BooleanTile(
                        title: 'Entretien déjà planifié',
                        subtitle:
                            'Un rendez-vous est prévu pour traiter les opérations à venir.',
                        value: _maintenancePlanned,
                        onChanged: (value) =>
                            _changed(() => _maintenancePlanned = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Signaux observés',
                  child: Column(
                    children: [
                      _BooleanTile(
                        title: 'Voyant ou message d’anomalie',
                        subtitle:
                            'Un signal inhabituel est visible au tableau de bord.',
                        value: _dashboardWarning,
                        important: true,
                        onChanged: (value) =>
                            _changed(() => _dashboardWarning = value),
                      ),
                      _BooleanTile(
                        title: 'Freinage inhabituel',
                        subtitle:
                            'Bruit, vibration, course ou efficacité inhabituelle.',
                        value: _brakingConcern,
                        important: true,
                        onChanged: (value) =>
                            _changed(() => _brakingConcern = value),
                      ),
                      _BooleanTile(
                        title: 'Pneumatique préoccupant',
                        subtitle:
                            'Usure, perte de pression ou comportement inhabituel.',
                        value: _tireConcern,
                        important: true,
                        onChanged: (value) =>
                            _changed(() => _tireConcern = value),
                      ),
                      _BooleanTile(
                        title: 'Démarrage moins fiable',
                        subtitle:
                            'Démarrage lent, aléatoire ou nécessitant plusieurs tentatives.',
                        value: _startingConcern,
                        onChanged: (value) =>
                            _changed(() => _startingConcern = value),
                      ),
                      _BooleanTile(
                        title: 'Température, fumée ou odeur anormale',
                        subtitle:
                            'Un signal lié au moteur ou au refroidissement est constaté.',
                        value: _engineCoolingConcern,
                        important: true,
                        onChanged: (value) =>
                            _changed(() => _engineCoolingConcern = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('risk-forecast-submit'),
                  onPressed: _saving ? null : _analyze,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(
                    _saving ? 'Analyse en cours…' : 'Analyser mes risques',
                  ),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 18),
                  _AssessmentView(
                    assessment: _assessment!,
                    onCopy: _copySummary,
                    onPlan: () => context.push<void>('/maintenance-planner'),
                  ),
                ],
                if (_recentAssessments.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _RecentAssessments(items: _recentAssessments),
                ],
              ],
            ),
    );
  }
}

class _ForecastIntro extends StatelessWidget {
  const _ForecastIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('risk-forecast-intro'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.query_stats_rounded, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            'Anticiper sans prétendre diagnostiquer',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'AutoClair croise l’âge, le kilométrage, l’entretien, l’usage et les '
            'signaux que vous déclarez. Le résultat reste une estimation '
            'préventive explicable, jamais un diagnostic mécanique.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentView extends StatelessWidget {
  const _AssessmentView({
    required this.assessment,
    required this.onCopy,
    required this.onPlan,
  });

  final RiskForecastAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onPlan;

  Color get _levelColor => switch (assessment.level) {
    RiskForecastLevel.low => AppColors.success,
    RiskForecastLevel.watch => AppColors.info,
    RiskForecastLevel.elevated => AppColors.warning,
    RiskForecastLevel.priority => AppColors.error,
  };

  Color get _levelBackground => switch (assessment.level) {
    RiskForecastLevel.low => AppColors.successSoft,
    RiskForecastLevel.watch => AppColors.infoSoft,
    RiskForecastLevel.elevated => AppColors.warningSoft,
    RiskForecastLevel.priority => AppColors.errorSoft,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          key: const ValueKey('risk-forecast-result'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _levelBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _levelColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Text(
                      '${assessment.score}',
                      style: TextStyle(
                        color: _levelColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assessment.level.label,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(assessment.level.guidance),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Indice préventif ${assessment.score}/100 · '
                '${assessment.dataConfidence.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (assessment.factors.isEmpty)
          const _SectionCard(
            title: 'Aucune priorité majeure détectée',
            child: Text(
              'Continuez à mettre à jour le kilométrage et les entretiens. '
              'L’absence de signal ne garantit pas l’absence de panne.',
            ),
          )
        else
          _SectionCard(
            title: 'Facteurs expliqués',
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < assessment.factors.length;
                  index++
                ) ...[
                  _FactorTile(factor: assessment.factors[index]),
                  if (index < assessment.factors.length - 1)
                    const Divider(height: 22),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.info),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cette estimation ne remplace ni le manuel du véhicule, ni un '
                  'contrôle professionnel. En cas de voyant rouge, de perte de '
                  'freinage, de surchauffe ou de comportement dangereux, arrêtez-vous en sécurité.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copier le résumé'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPlan,
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Planifier'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FactorTile extends StatelessWidget {
  const _FactorTile({required this.factor});

  final RiskForecastFactor factor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: factor.safetyCritical
                ? AppColors.errorSoft
                : AppColors.softPrimary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            factor.safetyCritical
                ? Icons.priority_high_rounded
                : Icons.insights_outlined,
            color: factor.safetyCritical ? AppColors.error : AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                factor.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(factor.detail),
              const SizedBox(height: 7),
              Text(
                factor.action,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                '${factor.category.label} · ${factor.horizon.label} · '
                '${factor.confidence.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentAssessments extends StatelessWidget {
  const _RecentAssessments({required this.items});

  final List<RiskForecastSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Analyses récentes',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.softPrimary,
                  child: Text('${items[index].score}'),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[index].level.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${_formatDate(items[index].createdAt)} · '
                        '${items[index].dataConfidence.label}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index < items.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.width,
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
  }
}

class _BooleanTile extends StatelessWidget {
  const _BooleanTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.important = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool important;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: important && value ? AppColors.error : null,
        ),
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
