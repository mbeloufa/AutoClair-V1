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
        _captured.add(current);
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

  Future<void> _capture(TirePhotoSlot slot) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _ensureInspection();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepKey, _stepIndex);
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo == null) {
        return;
      }
      final Uint8List bytes = await photo.readAsBytes();
      await _service.uploadPhoto(
        inspectionId: _inspectionId!,
        vehicleId: widget.vehicleId,
        slot: slot,
        bytes: bytes,
      );
      if (!mounted) {
        return;
      }
      setState(() => _captured.add(slot));
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
        const _HeroIllustration(),
        const SizedBox(height: 18),
        Text(
          '6 photos pour un pré-diagnostic visuel',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'AutoClair vous guide roue par roue. L’IA recherche les signes visibles d’usure ou de dommage et lit les marquages du flanc lorsqu’ils sont nets.',
        ),
        const SizedBox(height: 16),
        const _SafetyPanel(),
        const SizedBox(height: 16),
        const _MiniRule(
          icon: Icons.photo_camera_outlined,
          text:
              'Bande de roulement : 25 à 40 cm, presque face au pneu, rainures et épaules visibles.',
        ),
        const _MiniRule(
          icon: Icons.text_fields_rounded,
          text:
              'Flanc : 15 à 30 cm, appareil parallèle au flanc, dimension et marquages bien lisibles.',
        ),
        const _MiniRule(
          icon: Icons.light_mode_outlined,
          text:
              'Privilégiez un endroit lumineux et évitez une photo floue, sombre ou coupée.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Commencer le contrôle'),
        ),
        const SizedBox(height: 12),
        Text(
          'Cette analyse ne mesure pas une profondeur de sculpture certifiée et ne remplace jamais l’avis d’un professionnel.',
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
        ),
        const SizedBox(height: 12),
        Text(
          'Photo ${_stepIndex + 1} sur ${TirePhotoSlot.values.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Text(
          instruction.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _CaptureIllustration(slot: slot),
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
              for (final line in instruction.steps) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorMessage(message: _error!),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _capture(slot),
          icon: Icon(done ? Icons.refresh_rounded : Icons.photo_camera_rounded),
          label: Text(done ? 'Reprendre cette photo' : 'Prendre la photo'),
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
                ? 'Analyser les 6 photos'
                : 'Photo suivante',
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _restart,
          child: const Text('Annuler ce contrôle'),
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
            'État par pneu',
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
            'Caractéristiques lues',
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
              label: const Text('Comparer les prix des pneus'),
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
          label: const Text('Faire un nouveau contrôle'),
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
            'Prix constatés en ligne',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Prix unitaires indicatifs. Vérifiez toujours la dimension, les indices, la disponibilité, la livraison et le montage sur le site marchand.',
          ),
          const SizedBox(height: 12),
          if (offers.isEmpty)
            const Text(
              'Aucun prix actuel suffisamment vérifiable n’a été trouvé.',
            )
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
    required this.steps,
    required this.distance,
    required this.angle,
  });
  final String title;
  final List<String> steps;
  final String distance;
  final String angle;
}

_Instruction _instruction(TirePhotoSlot slot) => switch (slot) {
  TirePhotoSlot.frontLeftTread => const _Instruction(
    title: 'Pneu avant gauche — bande de roulement',
    steps: [
      'Frein à main serré, véhicule immobile sur sol plat.',
      'Mettez le contact ou démarrez uniquement pour braquer complètement à gauche.',
      'Coupez ensuite le moteur et le contact avant de sortir du véhicule.',
      'Cadrez toute la largeur de la bande de roulement, du centre aux deux épaules.',
    ],
    distance: '25–40 cm',
    angle: 'Presque face à la bande',
  ),
  TirePhotoSlot.frontRightTread => const _Instruction(
    title: 'Pneu avant droit — bande de roulement',
    steps: [
      'Remontez dans le véhicule avant de remettre le contact.',
      'Braquez complètement à droite puis coupez le moteur et le contact.',
      'Approchez-vous seulement lorsque le véhicule est totalement immobilisé.',
      'Cadrez les rainures centrales et les deux épaules du pneu.',
    ],
    distance: '25–40 cm',
    angle: 'Presque face à la bande',
  ),
  TirePhotoSlot.rearLeftTread => const _Instruction(
    title: 'Pneu arrière gauche — bande de roulement',
    steps: [
      'Laissez le moteur et le contact coupés.',
      'Placez le téléphone près du sol sans passer sous le véhicule.',
      'Cadrez toute la bande de roulement visible, sans zoom numérique.',
    ],
    distance: '25–40 cm',
    angle: 'Légèrement de biais si besoin',
  ),
  TirePhotoSlot.rearRightTread => const _Instruction(
    title: 'Pneu arrière droit — bande de roulement',
    steps: [
      'Laissez le moteur et le contact coupés.',
      'Placez le téléphone près du sol sans passer sous le véhicule.',
      'Cadrez toute la bande de roulement visible, sans zoom numérique.',
    ],
    distance: '25–40 cm',
    angle: 'Légèrement de biais si besoin',
  ),
  TirePhotoSlot.frontSidewall => const _Instruction(
    title: 'Pneu avant — flanc et dimension',
    steps: [
      'Photographiez le flanc d’un pneu avant, moteur coupé.',
      'Cherchez un marquage du type 205/55 R16 91V.',
      'Incluez si possible marque, modèle, M+S, 3PMSF, RunFlat et DOT visibles.',
    ],
    distance: '15–30 cm',
    angle: 'Téléphone parallèle au flanc',
  ),
  TirePhotoSlot.rearSidewall => const _Instruction(
    title: 'Pneu arrière — flanc et dimension',
    steps: [
      'Photographiez le flanc d’un pneu arrière, moteur coupé.',
      'Le texte doit être net et occuper une grande partie de l’image.',
      'Une dimension arrière différente de l’avant peut être normale : AutoClair ne la corrigera pas automatiquement.',
    ],
    distance: '15–30 cm',
    angle: 'Téléphone parallèle au flanc',
  ),
};

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primaryDark.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const CustomPaint(painter: _TireDiagramPainter()),
    );
  }
}

class _CaptureIllustration extends StatelessWidget {
  const _CaptureIllustration({required this.slot});
  final TirePhotoSlot slot;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: CustomPaint(painter: _TireDiagramPainter(slot: slot)),
    );
  }
}

class _TireDiagramPainter extends CustomPainter {
  const _TireDiagramPainter({this.slot});
  final TirePhotoSlot? slot;

  @override
  void paint(Canvas canvas, Size size) {
    final carPaint = Paint()..color = const Color(0xFF173B57);
    final tirePaint = Paint()..color = const Color(0xFF263238);
    final targetPaint = Paint()..color = const Color(0xFF00A67E);
    final linePaint = Paint()
      ..color = const Color(0xFF00A67E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.34,
        height: size.height * 0.72,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(body, carPaint);
    final wheelRects = <TirePhotoSlot, Rect>{
      TirePhotoSlot.frontLeftTread: Rect.fromCenter(
        center: Offset(size.width * 0.29, size.height * 0.30),
        width: 22,
        height: 54,
      ),
      TirePhotoSlot.frontRightTread: Rect.fromCenter(
        center: Offset(size.width * 0.71, size.height * 0.30),
        width: 22,
        height: 54,
      ),
      TirePhotoSlot.rearLeftTread: Rect.fromCenter(
        center: Offset(size.width * 0.29, size.height * 0.70),
        width: 22,
        height: 54,
      ),
      TirePhotoSlot.rearRightTread: Rect.fromCenter(
        center: Offset(size.width * 0.71, size.height * 0.70),
        width: 22,
        height: 54,
      ),
    };
    for (final entry in wheelRects.entries) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(entry.value, const Radius.circular(7)),
        entry.key == slot ? targetPaint : tirePaint,
      );
    }

    if (slot == TirePhotoSlot.frontSidewall ||
        slot == TirePhotoSlot.rearSidewall) {
      final center = Offset(
        size.width * 0.78,
        slot == TirePhotoSlot.frontSidewall
            ? size.height * 0.30
            : size.height * 0.70,
      );
      canvas.drawCircle(center, 42, tirePaint);
      canvas.drawCircle(center, 24, Paint()..color = const Color(0xFFF7F9FA));
      canvas.drawCircle(center, 48, linePaint);
      _text(
        canvas,
        '205/55 R16',
        Offset(center.dx - 46, center.dy + 55),
        12,
        const Color(0xFF173B57),
      );
    } else if (slot != null) {
      final rect = wheelRects[slot]!;
      final camera = Offset(
        slot == TirePhotoSlot.frontLeftTread ||
                slot == TirePhotoSlot.rearLeftTread
            ? size.width * 0.08
            : size.width * 0.92,
        rect.center.dy,
      );
      canvas.drawCircle(camera, 16, targetPaint);
      canvas.drawLine(camera, rect.center, linePaint);
      _text(
        canvas,
        '25–40 cm',
        Offset(size.width * 0.40, rect.center.dy - 22),
        12,
        const Color(0xFF173B57),
      );
    } else {
      canvas.drawCircle(
        Offset(size.width * 0.15, size.height * 0.50),
        18,
        targetPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.50),
        Offset(size.width * 0.29, size.height * 0.50),
        linePaint,
      );
      _text(
        canvas,
        '6 photos guidées',
        Offset(size.width * 0.08, size.height * 0.88),
        14,
        const Color(0xFF173B57),
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TireDiagramPainter oldDelegate) =>
      oldDelegate.slot != slot;
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
                  ? 'Sécurité : une analyse photo peut manquer un défaut non visible. En cas de doute, vibration, perte de pression, choc, hernie ou coupure, faites contrôler le pneu par un professionnel.'
                  : 'Sécurité : ne prenez jamais une photo avec le véhicule en mouvement. Braquez depuis le poste de conduite puis coupez le moteur et le contact avant de vous approcher des roues.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRule extends StatelessWidget {
  const _MiniRule({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
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
            'Confiance : ${_confidenceLabel(wheel.confidence)}',
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
            sidewall.axle == 'FRONT' ? 'Train avant' : 'Train arrière',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(details.where((item) => item.trim().isNotEmpty).join(' • ')),
          if (sidewall.markings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Marquages : ${sidewall.markings.join(', ')}'),
          ],
          if (sidewall.dotCode != null) ...[
            const SizedBox(height: 4),
            Text('DOT visible : ${sidewall.dotCode}'),
          ],
          const SizedBox(height: 6),
          Text(
            'Confiance de lecture : ${_confidenceLabel(sidewall.confidence)}',
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
            'Certaines photos doivent être reprises',
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
  'FRONT_LEFT' => 'Avant gauche',
  'FRONT_RIGHT' => 'Avant droit',
  'REAR_LEFT' => 'Arrière gauche',
  'REAR_RIGHT' => 'Arrière droit',
  _ => position,
};

String _slotLabel(String slot) => switch (slot) {
  'FRONT_LEFT_TREAD' => 'Pneu AVG',
  'FRONT_RIGHT_TREAD' => 'Pneu AVD',
  'REAR_LEFT_TREAD' => 'Pneu ARG',
  'REAR_RIGHT_TREAD' => 'Pneu ARD',
  'FRONT_SIDEWALL' => 'Flanc avant',
  'REAR_SIDEWALL' => 'Flanc arrière',
  _ => slot,
};

String _confidenceLabel(String confidence) => switch (confidence) {
  'HIGH' => 'élevée',
  'MEDIUM' => 'moyenne',
  _ => 'faible',
};

String _tireTypeLabel(String value) => switch (value) {
  'SUMMER' => 'été',
  'WINTER' => 'hiver',
  'ALL_SEASON' => '4 saisons',
  _ => 'type non déterminé',
};
