import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'tire_inspection_models.dart';
import 'tire_inspection_service.dart';

class TireInspectionPage extends StatefulWidget {
  const TireInspectionPage({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  State<TireInspectionPage> createState() => _TireInspectionPageState();
}

class _TireInspectionPageState extends State<TireInspectionPage> {
  final _picker = ImagePicker();
  final _service = TireInspectionService();
  final _captured = <TirePhotoSlot>{};
  final _qualityChecks = <TirePhotoSlot, TirePhotoQualityCheck>{};
  String? _inspectionId;
  int _stepIndex = -1;
  bool _busy = false;
  bool _restoring = true;
  String? _error;
  TireInspectionResult? _result;
  List<TireRetailOffer>? _offers;

  String get _draftKey => 'autoclair_tire_inspection_draft_${widget.vehicleId}';
  String get _stepKey => '${_draftKey}_step';

  @override
  void initState() {
    super.initState();
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_draftKey);
      final savedStep = prefs.getInt(_stepKey);
      if (savedId != null && savedId.isNotEmpty) {
        _inspectionId = savedId;
        _stepIndex = (savedStep ?? 0)
            .clamp(0, TirePhotoSlot.values.length - 1)
            .toInt();
        final remoteSlots = await _service.fetchCapturedSlots(savedId);
        for (final slot in TirePhotoSlot.values) {
          if (remoteSlots.contains(slot.apiValue)) {
            _captured.add(slot);
          }
        }
      }

      final lost = await _picker.retrieveLostData();
      if (!lost.isEmpty && lost.files?.isNotEmpty == true) {
        final currentIndex = _stepIndex
            .clamp(0, TirePhotoSlot.values.length - 1)
            .toInt();
        final current = TirePhotoSlot.values[currentIndex];
        final file = lost.files!.first;
        final bytes = await file.readAsBytes();
        await _ensureInspection();
        await _service.uploadPhoto(
          inspectionId: _inspectionId!,
          vehicleId: widget.vehicleId,
          slot: current,
          bytes: bytes,
        );
        final quality = await _service.validatePhoto(
          inspectionId: _inspectionId!,
          slot: current,
        );
        if (quality.accepted) {
          _captured.add(current);
          _qualityChecks[current] = quality;
        } else {
          await _service.discardPhoto(
            inspectionId: _inspectionId!,
            vehicleId: widget.vehicleId,
            slot: current,
          );
        }
      }
    } catch (_) {
      // Une restauration interrompue ne doit pas bloquer un nouveau contrôle.
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  Future<void> _ensureInspection() async {
    if (_inspectionId != null) {
      return;
    }
    final id = await _service.createInspection(widget.vehicleId);
    _inspectionId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, id);
  }

  Future<void> _start() async {
    setState(() {
      _stepIndex = 0;
      _error = null;
      _result = null;
      _offers = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey, 0);
  }

  Future<void> _choosePhoto(TirePhotoSlot slot) async {
    if (_busy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajouter la photo',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const ValueKey('tire-photo-camera'),
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Prendre une photo'),
                subtitle: const Text('Avec l’appareil photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                key: const ValueKey('tire-photo-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans mes photos'),
                subtitle: const Text('Utiliser une photo déjà prise'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndValidatePhoto(slot, source);
  }

  Future<void> _pickAndValidatePhoto(
    TirePhotoSlot slot,
    ImageSource source,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _qualityChecks.remove(slot);
      _captured.remove(slot);
    });
    try {
      await _ensureInspection();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepKey, _stepIndex);
      final photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (photo == null) return;

      final Uint8List bytes = await photo.readAsBytes();
      await _service.uploadPhoto(
        inspectionId: _inspectionId!,
        vehicleId: widget.vehicleId,
        slot: slot,
        bytes: bytes,
      );
      final quality = await _service.validatePhoto(
        inspectionId: _inspectionId!,
        slot: slot,
      );
      if (!quality.accepted) {
        await _service.discardPhoto(
          inspectionId: _inspectionId!,
          vehicleId: widget.vehicleId,
          slot: slot,
        );
        if (!mounted) return;
        setState(() {
          _error = [
            quality.message,
            if (quality.tip?.trim().isNotEmpty == true) quality.tip!.trim(),
          ].join(' ');
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _captured.add(slot);
        _qualityChecks[slot] = quality;
      });
    } on TireInspectionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_stepIndex < TirePhotoSlot.values.length - 1) {
      setState(() => _stepIndex++);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepKey, _stepIndex);
      return;
    }
    await _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    if (_inspectionId == null ||
        _captured.length < TirePhotoSlot.values.length ||
        _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _offers = null;
    });
    try {
      final result = await _service.analyze(_inspectionId!);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
      if (!result.needsRetake) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_draftKey);
        await prefs.remove(_stepKey);
      }
    } on TireInspectionException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _retakeRequired() async {
    final result = _result;
    if (result == null) {
      return;
    }
    var slot = TirePhotoSlot.frontLeftTread;
    for (final candidate in TirePhotoSlot.values) {
      if (result.retakeSlots.contains(candidate.apiValue)) {
        slot = candidate;
        break;
      }
    }
    setState(() {
      _result = null;
      _offers = null;
      _stepIndex = slot.index;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey, _stepIndex);
  }

  Future<void> _searchOffers() async {
    if (_inspectionId == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final offers = await _service.fetchOffers(_inspectionId!);
      if (mounted) {
        setState(() => _offers = offers);
      }
    } on TireInspectionException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openOffer(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => _error = 'Impossible d’ouvrir cette offre.');
      }
    }
  }

  Future<void> _restart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    await prefs.remove(_stepKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _inspectionId = null;
      _captured.clear();
      _stepIndex = -1;
      _result = null;
      _offers = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle des pneus')),
      body: SafeArea(
        child: _restoring
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _content(),
                ),
              ),
      ),
    );
  }

  Widget _content() {
    if (_result != null) {
      return _resultView(_result!);
    }
    if (_stepIndex < 0) {
      return _intro();
    }
    return _captureStep(TirePhotoSlot.values[_stepIndex]);
  }

  Widget _intro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TireExperienceHero(),
        const SizedBox(height: 20),
        Text(
          'Vos pneus, vérifiés en 6 photos',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Environ 3 minutes. AutoClair vous guide et vous dit simplement quoi surveiller.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BenefitPill(
              icon: Icons.visibility_outlined,
              label: 'Usure visible',
            ),
            _BenefitPill(
              icon: Icons.straighten_rounded,
              label: 'Taille du pneu',
            ),
            _BenefitPill(icon: Icons.euro_rounded, label: 'Prix si besoin'),
          ],
        ),
        const SizedBox(height: 18),
        const _SafetyPanel(),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text('Commencer — 6 photos'),
        ),
        const SizedBox(height: 10),
        Text(
          'Estimation automatisée, informative uniquement — jamais un contrôle professionnel.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _captureStep(TirePhotoSlot slot) {
    final instruction = _instruction(slot);
    final done = _captured.contains(slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_stepIndex + 1) / TirePhotoSlot.values.length,
          minHeight: 7,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 12),
        Text(
          'Étape ${_stepIndex + 1} sur ${TirePhotoSlot.values.length}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          instruction.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          instruction.goal,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        _PhotoGuideImage(slot: slot),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Faites comme ceci',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (
                var index = 0;
                index < instruction.steps.length;
                index++
              ) ...[
                _NumberedStep(
                  number: index + 1,
                  text: instruction.steps[index],
                ),
                if (index != instruction.steps.length - 1)
                  const SizedBox(height: 9),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HintChip(
                    icon: Icons.straighten_rounded,
                    label: instruction.distance,
                  ),
                  _HintChip(
                    icon: Icons.photo_camera_outlined,
                    label: instruction.angle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AvoidChip(icon: Icons.blur_on_rounded, label: 'Pas flou'),
                  _AvoidChip(
                    icon: Icons.dark_mode_outlined,
                    label: 'Pas sombre',
                  ),
                  _AvoidChip(
                    icon: Icons.zoom_out_rounded,
                    label: 'Pas trop loin',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const _PhotoQualityStatusCard(
            icon: Icons.image_search_rounded,
            title: 'Vérification de la photo…',
            message:
                'AutoClair vérifie uniquement le cadrage, la netteté et la lumière.',
          ),
        ] else if (_qualityChecks[slot] case final quality?) ...[
          const SizedBox(height: 12),
          _PhotoQualityStatusCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'Photo validée',
            message: quality.message,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorMessage(message: _error!),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _choosePhoto(slot),
          icon: Icon(done ? Icons.refresh_rounded : Icons.photo_camera_rounded),
          label: Text(done ? 'Remplacer la photo' : 'Ajouter la photo'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: done && !_busy ? _next : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _stepIndex == TirePhotoSlot.values.length - 1
                      ? Icons.auto_awesome_rounded
                      : Icons.arrow_forward_rounded,
                ),
          label: Text(
            _stepIndex == TirePhotoSlot.values.length - 1
                ? 'Voir mon résultat'
                : 'Photo suivante',
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _restart,
          child: const Text('Arrêter'),
        ),
      ],
    );
  }

  Widget _resultView(TireInspectionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlobalResultCard(result: result),
        const SizedBox(height: 14),
        const _SafetyPanel(resultMode: true),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorMessage(message: _error!),
        ],
        if (result.needsRetake) ...[
          const SizedBox(height: 16),
          _RetakeCard(result: result),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _retakeRequired,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Reprendre les photos demandées'),
          ),
        ] else ...[
          const SizedBox(height: 20),
          Text(
            'Ce qu’AutoClair voit',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final wheel in result.wheels) ...[
            _WheelResultCard(wheel: wheel),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          Text(
            'Informations lues sur vos pneus',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final sidewall in result.sidewalls) ...[
            _SidewallCard(sidewall: sidewall),
            const SizedBox(height: 10),
          ],
          if (result.replacementRecommended &&
              (result.frontDimension != null ||
                  result.rearDimension != null)) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _searchOffers,
              icon: const Icon(Icons.price_check_outlined),
              label: const Text('Voir des prix en ligne'),
            ),
          ],
          if (_offers != null) ...[
            const SizedBox(height: 14),
            _offerSection(_offers!),
          ],
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restart,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Refaire le contrôle'),
        ),
      ],
    );
  }

  Widget _offerSection(List<TireRetailOffer> offers) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prix en ligne',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Vérifiez le pneu, la livraison et le montage sur le site marchand.',
          ),
          const SizedBox(height: 12),
          if (offers.isEmpty)
            const Text('Aucun prix fiable trouvé pour le moment.')
          else
            for (final offer in offers) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  offer.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${offer.merchant} • ${offer.dimension} • ${offer.tireType}',
                ),
                trailing: Text(
                  '${offer.unitPriceEur.toStringAsFixed(2).replaceAll('.', ',')} €',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onTap: () => unawaited(_openOffer(offer.url)),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _Instruction {
  const _Instruction({
    required this.title,
    required this.goal,
    required this.steps,
    required this.distance,
    required this.angle,
  });

  final String title;
  final String goal;
  final List<String> steps;
  final String distance;
  final String angle;
}

_Instruction _instruction(TirePhotoSlot slot) => switch (slot) {
  TirePhotoSlot.frontLeftTread => const _Instruction(
    title: 'Roue avant gauche',
    goal: 'Photographiez la partie du pneu qui touche la route.',
    steps: [
      'Serrez le frein à main.',
      'Braquez à gauche, puis coupez le moteur.',
      'Sortez et prenez la photo à environ 30 cm.',
    ],
    distance: 'À ~30 cm',
    angle: 'Face au pneu',
  ),
  TirePhotoSlot.frontRightTread => const _Instruction(
    title: 'Roue avant droite',
    goal: 'Photographiez la partie du pneu qui touche la route.',
    steps: [
      'Remontez dans la voiture.',
      'Braquez à droite, puis coupez le moteur.',
      'Sortez et prenez la photo à environ 30 cm.',
    ],
    distance: 'À ~30 cm',
    angle: 'Face au pneu',
  ),
  TirePhotoSlot.rearLeftTread => const _Instruction(
    title: 'Roue arrière gauche',
    goal: 'Photographiez la partie du pneu qui touche la route.',
    steps: [
      'Laissez le moteur coupé.',
      'Placez le téléphone près du sol, sans passer sous la voiture.',
      'Cadrez toute la largeur visible du pneu.',
    ],
    distance: 'À ~30 cm',
    angle: 'Face au pneu',
  ),
  TirePhotoSlot.rearRightTread => const _Instruction(
    title: 'Roue arrière droite',
    goal: 'Photographiez la partie du pneu qui touche la route.',
    steps: [
      'Laissez le moteur coupé.',
      'Placez le téléphone près du sol, sans passer sous la voiture.',
      'Cadrez toute la largeur visible du pneu.',
    ],
    distance: 'À ~30 cm',
    angle: 'Face au pneu',
  ),
  TirePhotoSlot.frontSidewall => const _Instruction(
    title: 'Une roue avant',
    goal: 'Photographiez les chiffres écrits sur le côté du pneu.',
    steps: [
      'Laissez le moteur coupé.',
      'Cherchez une ligne comme 205/55 R16.',
      'Approchez le téléphone pour que les chiffres soient nets.',
    ],
    distance: 'À ~20 cm',
    angle: 'Face aux chiffres',
  ),
  TirePhotoSlot.rearSidewall => const _Instruction(
    title: 'Une roue arrière',
    goal: 'Photographiez les chiffres écrits sur le côté du pneu.',
    steps: [
      'Laissez le moteur coupé.',
      'Cherchez une ligne comme 205/55 R16.',
      'Approchez le téléphone pour que les chiffres soient nets.',
    ],
    distance: 'À ~20 cm',
    angle: 'Face aux chiffres',
  ),
};

class _TireExperienceHero extends StatelessWidget {
  const _TireExperienceHero();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Voiture et téléphone utilisés pour le contrôle photo des pneus',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/tire_inspection/tire_intro.png',
          height: 235,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _PhotoGuideImage extends StatelessWidget {
  const _PhotoGuideImage({required this.slot});

  final TirePhotoSlot slot;

  @override
  Widget build(BuildContext context) {
    final asset = slot.isTread
        ? 'assets/tire_inspection/tire_tread_photo.png'
        : 'assets/tire_inspection/tire_sidewall_photo.png';
    final semantics = slot.isTread
        ? 'Personne accroupie prenant la partie du pneu qui touche la route en photo, avec position, distance et angle visibles'
        : 'Personne accroupie photographiant les inscriptions sur le côté du pneu, avec position, distance et angle visibles';
    return Semantics(
      label: semantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          asset,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _AvoidChip extends StatelessWidget {
  const _AvoidChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({this.resultMode = false});
  final bool resultMode;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resultMode
                  ? 'AutoClair fournit une estimation visuelle automatisée à titre informatif. Elle ne constitue ni un contrôle, ni un diagnostic, ni un avis professionnel et ne garantit pas l’état ou la sécurité des pneus. Vous restez responsable des vérifications, décisions et de l’utilisation du véhicule. Toute anomalie, tout doute ou toute dégradation doit être contrôlé par un professionnel avant de rouler.'
                  : 'Toujours à l’arrêt. Pour les roues avant, braquez puis coupez le moteur avant de sortir.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GlobalResultCard extends StatelessWidget {
  const _GlobalResultCard({required this.result});
  final TireInspectionResult result;
  @override
  Widget build(BuildContext context) {
    final color = _levelColor(result.globalLevel);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tire_repair_outlined, size: 38, color: color),
          const SizedBox(height: 10),
          Text(
            tireInspectionLevelLabel(result.globalLevel),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(result.summary),
          if (result.professionalMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.professionalMessage,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _WheelResultCard extends StatelessWidget {
  const _WheelResultCard({required this.wheel});
  final TireWheelAssessment wheel;
  @override
  Widget build(BuildContext context) {
    final color = _levelColor(wheel.level);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _wheelLabel(wheel.position),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                tireInspectionLevelLabel(wheel.level),
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          if (wheel.treadAssessment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(wheel.treadAssessment),
          ],
          for (final finding in wheel.visibleFindings)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('• $finding'),
            ),
          const SizedBox(height: 6),
          Text(
            'Lecture photo : ${_confidenceLabel(wheel.confidence)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SidewallCard extends StatelessWidget {
  const _SidewallCard({required this.sidewall});
  final TireSidewallAssessment sidewall;
  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (sidewall.dimension != null) sidewall.dimension!,
      if (sidewall.loadSpeedIndex != null) sidewall.loadSpeedIndex!,
      if (sidewall.brand != null) sidewall.brand!,
      if (sidewall.model != null) sidewall.model!,
      _tireTypeLabel(sidewall.tireType),
    ];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sidewall.axle == 'FRONT' ? 'Pneus avant' : 'Pneus arrière',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(details.where((item) => item.trim().isNotEmpty).join(' • ')),
          if (sidewall.markings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Indications visibles : ${sidewall.markings.join(', ')}'),
          ],
          if (sidewall.dotCode != null) ...[
            const SizedBox(height: 4),
            Text('Code de fabrication lu : ${sidewall.dotCode}'),
          ],
          const SizedBox(height: 6),
          Text(
            'Lecture photo : ${_confidenceLabel(sidewall.confidence)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RetakeCard extends StatelessWidget {
  const _RetakeCard({required this.result});
  final TireInspectionResult result;
  @override
  Widget build(BuildContext context) {
    final bad = result.photoQuality
        .where((item) => item.status == 'RETAKE')
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Une photo n’est pas assez claire',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          for (final item in bad)
            Text('• ${_slotLabel(item.slot)} : ${item.reason}'),
        ],
      ),
    );
  }
}

class _PhotoQualityStatusCard extends StatelessWidget {
  const _PhotoQualityStatusCard({
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

Color _levelColor(TireInspectionLevel level) => switch (level) {
  TireInspectionLevel.ok => AppColors.success,
  TireInspectionLevel.watch => AppColors.warning,
  TireInspectionLevel.replaceSoon => AppColors.warning,
  TireInspectionLevel.replaceNow => AppColors.error,
  TireInspectionLevel.urgentProfessionalCheck => AppColors.error,
  TireInspectionLevel.unknown => AppColors.textMuted,
};

String _wheelLabel(String position) => switch (position) {
  'FRONT_LEFT' => 'Roue avant gauche',
  'FRONT_RIGHT' => 'Roue avant droite',
  'REAR_LEFT' => 'Roue arrière gauche',
  'REAR_RIGHT' => 'Roue arrière droite',
  _ => position,
};

String _slotLabel(String slot) => switch (slot) {
  'FRONT_LEFT_TREAD' => 'Roue avant gauche',
  'FRONT_RIGHT_TREAD' => 'Roue avant droite',
  'REAR_LEFT_TREAD' => 'Roue arrière gauche',
  'REAR_RIGHT_TREAD' => 'Roue arrière droite',
  'FRONT_SIDEWALL' => 'Côté d’un pneu avant',
  'REAR_SIDEWALL' => 'Côté d’un pneu arrière',
  _ => slot,
};

String _confidenceLabel(String confidence) => switch (confidence) {
  'HIGH' => 'claire',
  'MEDIUM' => 'correcte',
  _ => 'difficile',
};

String _tireTypeLabel(String value) => switch (value) {
  'SUMMER' => 'été',
  'WINTER' => 'hiver',
  'ALL_SEASON' => '4 saisons',
  _ => 'type non déterminé',
};
