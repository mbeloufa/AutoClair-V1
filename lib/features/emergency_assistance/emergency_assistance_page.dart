import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'emergency_models.dart';
import 'emergency_safety_engine.dart';
import 'emergency_service.dart';

class EmergencyAssistancePage extends StatefulWidget {
  const EmergencyAssistancePage({super.key});

  @override
  State<EmergencyAssistancePage> createState() =>
      _EmergencyAssistancePageState();
}

class _EmergencyAssistancePageState extends State<EmergencyAssistancePage> {
  final _service = EmergencyAssistanceService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  final _descriptionController = TextEditingController();
  final _clarificationController = TextEditingController();
  final _providerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contractController = TextEditingController();
  final _coverageController = TextEditingController();

  List<EmergencyVehicleOption> _vehicles = const [];
  EmergencyVehicleOption? _vehicle;
  EmergencyCategory _category = EmergencyCategory.warningLight;
  EmergencyRoadContext _roadContext = EmergencyRoadContext.unknown;
  bool? _stoppedSafe;

  bool _injury = false;
  bool _fireOrHeavySmoke = false;
  bool _fuelSmellOrLeak = false;
  bool _brakeLoss = false;
  bool _steeringLoss = false;
  bool _overheat = false;
  bool _stopMessage = false;
  bool _highVoltageDamage = false;
  bool _vehicleInTrafficLane = false;
  bool _severeTireDamage = false;
  bool _redWarning = false;
  bool _flashingWarning = false;
  bool _lossOfPower = false;
  bool _abnormalBrakingNoise = false;

  Position? _position;
  final List<EmergencyPendingMedia> _pendingMedia = [];
  bool _recording = false;
  String? _recordingPath;

  bool _loading = true;
  bool _processing = false;
  bool _savingProfile = false;
  bool _loadingProfile = false;
  String? _error;
  String? _sessionId;
  EmergencyAssessmentResult? _result;
  String? _savedEventId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _clarificationController.dispose();
    _providerController.dispose();
    _phoneController.dispose();
    _contractController.dispose();
    _coverageController.dispose();
    _audioRecorder.dispose();
    final recordingPath = _recordingPath;
    if (recordingPath != null) {
      try {
        File(recordingPath).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  EmergencySafetyFlags get _flags => EmergencySafetyFlags(
    injury: _injury,
    fireOrHeavySmoke: _fireOrHeavySmoke,
    fuelSmellOrLeak: _fuelSmellOrLeak,
    brakeLoss: _brakeLoss,
    steeringLoss: _steeringLoss,
    overheat: _overheat,
    stopMessage: _stopMessage,
    highVoltageDamage: _highVoltageDamage,
    vehicleInTrafficLane: _vehicleInTrafficLane,
    severeTireDamage: _severeTireDamage,
    redWarning: _redWarning,
    flashingWarning: _flashingWarning,
    lossOfPower: _lossOfPower,
    abnormalBrakingNoise: _abnormalBrakingNoise,
  );

  EmergencySafetyDecision get _localDecision =>
      EmergencySafetyDecision.evaluate(category: _category, flags: _flags);

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _service.fetchVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _vehicle = vehicles.isEmpty ? null : vehicles.first;
        _loading = false;
      });
      if (_vehicle != null) {
        await _loadAssistanceProfile(_vehicle!.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Les données en ligne ne sont pas disponibles. Les consignes de sécurité restent accessibles.';
      });
    }
  }

  Future<void> _loadAssistanceProfile(String vehicleId) async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await _service.fetchAssistanceProfile(vehicleId);
      if (!mounted) return;
      _providerController.text = profile.providerName;
      _phoneController.text = profile.phoneNumber;
      _contractController.text = profile.contractNumber;
      _coverageController.text = profile.coverageNote;
      setState(() => _loadingProfile = false);
    } catch (_) {
      if (!mounted) return;
      _providerController.clear();
      _phoneController.clear();
      _contractController.clear();
      _coverageController.clear();
      setState(() => _loadingProfile = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _selectVehicle(EmergencyVehicleOption? vehicle) async {
    if (vehicle == null || _sessionId != null) return;
    setState(() {
      _vehicle = vehicle;
      _result = null;
      _savedEventId = null;
    });
    await _loadAssistanceProfile(vehicle.id);
  }

  void _selectCategory(EmergencyCategory category) {
    if (_sessionId != null || _processing) return;
    setState(() {
      _category = category;
      _result = null;
      if (category == EmergencyCategory.immobilized) {
        _lossOfPower = false;
      }
    });
  }

  Future<void> _choosePhotoSource() async {
    if (_processing || _pendingMedia.length >= 3) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        _showMessage('La photo doit faire moins de 10 Mo.');
        return;
      }
      final mime =
          file.mimeType ??
          (file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      if (!mounted) return;
      setState(() {
        _pendingMedia.add(
          EmergencyPendingMedia(
            kind: 'photo',
            bytes: bytes,
            fileName: file.name,
            mimeType: mime,
          ),
        );
      });
    } catch (error) {
      _showMessage('La photo n’a pas pu être ajoutée.');
    }
  }

  Future<void> _toggleRecording() async {
    if (_processing) return;

    if (_recording) {
      try {
        final path = await _audioRecorder.stop();
        final localPath = path ?? _recordingPath;
        _recordingPath = null;
        if (localPath == null) {
          throw StateError('Enregistrement introuvable.');
        }

        final file = File(localPath);
        final bytes = await file.readAsBytes();
        try {
          await file.delete();
        } catch (_) {}

        if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
          _showMessage('Le son doit faire moins de 10 Mo.');
          if (mounted) setState(() => _recording = false);
          return;
        }

        if (!mounted) return;
        setState(() {
          _recording = false;
          if (_pendingMedia.length < 3) {
            _pendingMedia.add(
              EmergencyPendingMedia(
                kind: 'audio',
                bytes: bytes,
                fileName: 'bruit_${DateTime.now().millisecondsSinceEpoch}.m4a',
                mimeType: 'audio/mp4',
              ),
            );
          }
        });
        return;
      } catch (_) {
        if (mounted) setState(() => _recording = false);
        _showMessage('L’enregistrement n’a pas pu être conservé.');
        return;
      }
    }

    if (_pendingMedia.length >= 3) {
      _showMessage('Trois fichiers maximum par assistance.');
      return;
    }

    try {
      final allowed = await _audioRecorder.hasPermission();
      if (!allowed) {
        _showMessage(
          'Autorisez le microphone pour enregistrer un bruit du véhicule.',
        );
        return;
      }
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'autoclair_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recordingPath = path;
        _recording = true;
      });
    } catch (_) {
      _showMessage('Le microphone n’est pas disponible.');
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_processing) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Activez la localisation pour utiliser votre position.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'La position n’est pas partagée. Vous pouvez continuer sans localisation.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() => _position = position);
    } catch (_) {
      _showMessage(
        'La position n’a pas pu être obtenue. Vous pouvez continuer sans elle.',
      );
    }
  }

  Future<void> _saveProfile() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;
    setState(() => _savingProfile = true);
    try {
      await _service.saveAssistanceProfile(
        vehicleId: vehicle.id,
        providerName: _providerController.text,
        phoneNumber: _phoneController.text,
        contractNumber: _contractController.text,
        coverageNote: _coverageController.text,
      );
      _showMessage('Informations d’assistance enregistrées.');
    } catch (_) {
      _showMessage(
        'Les informations d’assistance n’ont pas pu être enregistrées.',
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _callNumber(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      _showMessage('Aucun numéro d’assistance enregistré.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: clean);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Impossible d’ouvrir l’application Téléphone.');
    }
  }

  Future<void> _analyze() async {
    if (_stoppedSafe != true) {
      _showMessage(
        'Utilisez l’assistant uniquement lorsque vous êtes arrêté dans un endroit sûr.',
      );
      return;
    }
    final vehicle = _vehicle;
    if (vehicle == null) {
      _showMessage('Sélectionnez un véhicule.');
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.length < 5 &&
        _localDecision.level.rank < EmergencySafetyLevel.stop.rank) {
      _showMessage('Décrivez brièvement ce que vous observez.');
      return;
    }

    if (_recording) {
      await _toggleRecording();
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      var sessionId = _sessionId;
      if (sessionId == null) {
        sessionId = await _service.createSession(
          vehicle: vehicle,
          category: _category,
          roadContext: _roadContext,
          description: description,
          flags: _flags,
          latitude: _position?.latitude,
          longitude: _position?.longitude,
          locationAccuracyM: _position?.accuracy,
        );
        _sessionId = sessionId;
      } else {
        await _service.updateSession(
          sessionId: sessionId,
          category: _category,
          roadContext: _roadContext,
          description: description,
          flags: _flags,
          latitude: _position?.latitude,
          longitude: _position?.longitude,
          locationAccuracyM: _position?.accuracy,
        );
      }

      while (_pendingMedia.isNotEmpty) {
        final media = _pendingMedia.first;
        await _service.uploadMedia(sessionId: sessionId, media: media);
        _pendingMedia.removeAt(0);
      }

      final result = await _service.analyzeSession(sessionId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _processing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error =
            'L’analyse intelligente n’est pas disponible pour le moment. '
            'La décision de sécurité locale ci-dessus reste active.';
      });
    }
  }

  Future<void> _reanalyze() async {
    final sessionId = _sessionId;
    final text = _clarificationController.text.trim();
    if (sessionId == null || text.isEmpty) return;

    setState(() => _processing = true);
    try {
      await _service.addClarification(sessionId: sessionId, text: text);
      await _service.updateSession(
        sessionId: sessionId,
        category: _category,
        roadContext: _roadContext,
        description: _descriptionController.text,
        flags: _flags,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        locationAccuracyM: _position?.accuracy,
      );
      final result = await _service.analyzeSession(sessionId);
      if (!mounted) return;
      setState(() {
        _clarificationController.clear();
        _result = result;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error =
            'La précision n’a pas pu être analysée. La décision de sécurité locale reste disponible.';
      });
    }
  }

  Future<void> _copyGarageSummary() async {
    final vehicle = _vehicle;
    final result = _result;
    if (vehicle == null || result == null) return;

    final mileageText = vehicle.mileage == null
        ? 'non renseigné'
        : '${vehicle.mileage} km';

    final buffer = StringBuffer()
      ..writeln('AutoClair - Résumé de l’incident')
      ..writeln()
      ..writeln('Véhicule : ${vehicle.displayName}')
      ..writeln('Kilométrage : $mileageText')
      ..writeln('Situation : ${_category.label}')
      ..writeln('Décision AutoClair : ${result.headline}')
      ..writeln()
      ..writeln('Description :')
      ..writeln(_descriptionController.text.trim());

    if (result.reasons.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Éléments relevés :');
      for (final reason in result.reasons) {
        buffer.writeln('- $reason');
      }
    }

    if (result.uncertainties.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('À vérifier :');
      for (final uncertainty in result.uncertainties) {
        buffer.writeln('- $uncertainty');
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    _showMessage('Résumé copié. Vous pouvez le transmettre au garage.');
  }

  Future<void> _saveIncident() async {
    final sessionId = _sessionId;
    final result = _result;
    if (sessionId == null || result == null) return;

    setState(() => _processing = true);
    try {
      final eventId = await _service.saveIncident(
        sessionId: sessionId,
        result: result,
      );
      if (!mounted) return;
      setState(() {
        _savedEventId = eventId;
        _processing = false;
      });
      _showMessage('Incident ajouté à l’historique du véhicule.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showMessage('L’incident n’a pas pu être enregistré.');
    }
  }

  Future<void> _deleteCurrentAssistance() async {
    final sessionId = _sessionId;
    if (sessionId == null || _processing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette assistance ?'),
        content: const Text(
          'Les photos, sons et analyses de cette assistance seront supprimés. '
          'Un incident déjà ajouté à l’historique du véhicule reste conservé.',
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
      await _service.deleteSession(sessionId);
      if (!mounted) return;
      setState(() {
        _processing = false;
        _sessionId = null;
        _result = null;
        _savedEventId = null;
        _pendingMedia.clear();
        _clarificationController.clear();
        _descriptionController.clear();
        _position = null;
        _stoppedSafe = null;
        _resetFlags();
      });
      _showMessage('Dossier d’assistance supprimé.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showMessage('Le dossier n’a pas pu être supprimé.');
    }
  }

  void _newAssistance() {
    if (_processing || _recording) return;
    setState(() {
      _sessionId = null;
      _result = null;
      _savedEventId = null;
      _pendingMedia.clear();
      _clarificationController.clear();
      _descriptionController.clear();
      _stoppedSafe = null;
      _position = null;
      _roadContext = EmergencyRoadContext.unknown;
      _resetFlags();
    });
  }

  void _resetFlags() {
    _injury = false;
    _fireOrHeavySmoke = false;
    _fuelSmellOrLeak = false;
    _brakeLoss = false;
    _steeringLoss = false;
    _overheat = false;
    _stopMessage = false;
    _highVoltageDamage = false;
    _vehicleInTrafficLane = false;
    _severeTireDamage = false;
    _redWarning = false;
    _flashingWarning = false;
    _lossOfPower = false;
    _abnormalBrakingNoise = false;
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _safetyStartCard() {
    return _sectionCard(
      title: 'Avant tout',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Utilisez AutoClair uniquement à l’arrêt. Si vous conduisez encore, '
            'ne manipulez pas votre téléphone et rejoignez un endroit sûr si la situation le permet.',
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.check_circle_outline),
                label: Text('Je suis arrêté'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.directions_car_filled_outlined),
                label: Text('Je roule encore'),
              ),
            ],
            selected: _stoppedSafe == null ? const {} : {_stoppedSafe!},
            emptySelectionAllowed: true,
            onSelectionChanged: _processing
                ? null
                : (selection) {
                    setState(() {
                      _stoppedSafe = selection.isEmpty ? null : selection.first;
                    });
                  },
          ),
          if (_stoppedSafe == false) ...[
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'N’utilisez pas l’assistant en conduisant. '
                  'En cas de danger immédiat, privilégiez la mise en sécurité et les secours.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryCard() {
    return _sectionCard(
      title: 'Que se passe-t-il ?',
      child: Column(
        children: EmergencyCategory.values
            .map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: _category == category
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('emergency-category-${category.dbValue}'),
                    onTap: _sessionId == null && !_processing
                        ? () => _selectCategory(category)
                        : null,
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

  Widget _vehicleContextCard() {
    return _sectionCard(
      title: 'Véhicule et contexte',
      child: Column(
        children: [
          if (_vehicles.isEmpty)
            const Text(
              'Aucun véhicule chargé. Les consignes de sécurité locales restent disponibles.',
            )
          else
            DropdownButtonFormField<EmergencyVehicleOption>(
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
              onChanged: _sessionId == null && !_processing
                  ? _selectVehicle
                  : null,
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EmergencyRoadContext>(
            initialValue: _roadContext,
            decoration: const InputDecoration(labelText: 'Où êtes-vous ?'),
            items: EmergencyRoadContext.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: _processing
                ? null
                : (value) => setState(
                    () => _roadContext = value ?? EmergencyRoadContext.unknown,
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _processing ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location_outlined),
            label: Text(
              _position == null
                  ? 'Utiliser ma position pour cette assistance'
                  : 'Position ajoutée • précision ${_position!.accuracy.round()} m',
            ),
          ),
          if (_roadContext == EmergencyRoadContext.motorway) ...[
            const SizedBox(height: 10),
            const Text(
              'Autoroute / voie rapide : privilégiez la mise à l’abri hors de la circulation '
              'et les moyens d’assistance prévus sur place. Ne vous exposez pas pour effectuer une réparation.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _riskChecksCard() {
    return _sectionCard(
      title: 'Signes importants',
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Cochez seulement ce que vous observez réellement. '
              'Ces règles de sécurité fonctionnent même si l’analyse IA est indisponible.',
            ),
          ),
          _riskSwitch(
            'Une personne est blessée',
            _injury,
            (value) => _injury = value,
          ),
          _riskSwitch(
            'Feu ou fumée importante',
            _fireOrHeavySmoke,
            (value) => _fireOrHeavySmoke = value,
          ),
          _riskSwitch(
            'Forte odeur ou fuite de carburant',
            _fuelSmellOrLeak,
            (value) => _fuelSmellOrLeak = value,
          ),
          _riskSwitch(
            'Freinage fortement dégradé',
            _brakeLoss,
            (value) => _brakeLoss = value,
          ),
          _riskSwitch(
            'Direction fortement dégradée',
            _steeringLoss,
            (value) => _steeringLoss = value,
          ),
          _riskSwitch(
            'Surchauffe moteur',
            _overheat,
            (value) => _overheat = value,
          ),
          _riskSwitch(
            'Message STOP explicite',
            _stopMessage,
            (value) => _stopMessage = value,
          ),
          _riskSwitch(
            'Dommage possible batterie haute tension',
            _highVoltageDamage,
            (value) => _highVoltageDamage = value,
          ),
          _riskSwitch(
            'Véhicule immobilisé dans une voie circulée',
            _vehicleInTrafficLane,
            (value) => _vehicleInTrafficLane = value,
          ),
          _riskSwitch(
            'Pneu fortement endommagé / déformé',
            _severeTireDamage,
            (value) => _severeTireDamage = value,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Autres signes'),
            children: [
              _riskSwitch(
                'Voyant rouge',
                _redWarning,
                (value) => _redWarning = value,
              ),
              _riskSwitch(
                'Voyant clignotant',
                _flashingWarning,
                (value) => _flashingWarning = value,
              ),
              _riskSwitch(
                'Perte de puissance',
                _lossOfPower,
                (value) => _lossOfPower = value,
              ),
              _riskSwitch(
                'Bruit inhabituel pendant le freinage',
                _abnormalBrakingNoise,
                (value) => _abnormalBrakingNoise = value,
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

  Widget _localDecisionCard() {
    final decision = _localDecision;
    final color = decision.level == EmergencySafetyLevel.stop
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    return Material(
      key: const ValueKey('emergency-local-safety-decision'),
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              decision.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...decision.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $reason'),
              ),
            ),
            const SizedBox(height: 6),
            ...decision.actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (decision.callEmergencyServices) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _callNumber('112'),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Contacter les secours • 112'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _descriptionAndMediaCard() {
    return _sectionCard(
      title: 'Montrez ou décrivez le problème',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Que voyez-vous ou ressentez-vous ?',
              hintText:
                  'Ex. voyant orange fixe, clics au démarrage, vibration au freinage…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _pendingMedia.length < 3 && !_processing
                    ? _choosePhotoSource
                    : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Ajouter une photo'),
              ),
              FilledButton.tonalIcon(
                onPressed: !_processing ? _toggleRecording : null,
                icon: Icon(
                  _recording
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_outlined,
                ),
                label: Text(
                  _recording ? 'Arrêter le son' : 'Enregistrer un son',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Le son est conservé comme pièce de l’incident et peut être montré au garage. '
            'AutoClair ne l’utilise pas pour identifier précisément une panne.',
          ),
          if (_pendingMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_pendingMedia.length, (index) {
                final media = _pendingMedia[index];
                return InputChip(
                  avatar: Icon(
                    media.isPhoto
                        ? Icons.image_outlined
                        : Icons.graphic_eq_outlined,
                    size: 18,
                  ),
                  label: Text(media.isPhoto ? 'Photo' : 'Son'),
                  onDeleted: _processing
                      ? null
                      : () => setState(() => _pendingMedia.removeAt(index)),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assistanceProfileCard() {
    return _sectionCard(
      title: 'Mon assistance',
      child: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TextField(
                  controller: _providerController,
                  decoration: const InputDecoration(
                    labelText: 'Assureur / assistance',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone assistance',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contractController,
                  decoration: const InputDecoration(labelText: 'N° de contrat'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _coverageController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Note utile',
                    hintText: 'Ex. assistance 0 km',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingProfile || _vehicle == null
                            ? null
                            : _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Enregistrer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _phoneController.text.trim().isEmpty
                            ? null
                            : () => _callNumber(_phoneController.text),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Appeler'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _resultCard(EmergencyAssessmentResult result) {
    return _sectionCard(
      title: result.headline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.summary,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (result.reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Pourquoi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...result.reasons.map((value) => Text('• $value')),
          ],
          if (result.imageObservations.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Ce qui est visible sur les photos',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...result.imageObservations.map((value) => Text('• $value')),
          ],
          if (result.actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'À faire maintenant',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...result.actions.map(
              (action) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${action.priority}')),
                title: Text(
                  action.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(action.description),
              ),
            ),
          ],
          if (result.uncertainties.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ce qui reste incertain'),
              children: result.uncertainties
                  .map(
                    (value) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.help_outline_rounded),
                      title: Text(value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (result.audioNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(result.audioNote),
          ],
          if (result.needsInformation) ...[
            const SizedBox(height: 14),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Il me manque quelques précisions',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    ...result.followUpQuestions.map(
                      (question) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('• $question'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clarificationController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Vos précisions',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _processing ? null : _reanalyze,
                      child: const Text('Analyser ces précisions'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (result.callEmergencyServices)
                FilledButton.icon(
                  onPressed: () => _callNumber('112'),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Secours • 112'),
                ),
              FilledButton.tonalIcon(
                onPressed: _phoneController.text.trim().isEmpty
                    ? null
                    : () => _callNumber(_phoneController.text),
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('Mon assistance'),
              ),
              OutlinedButton.icon(
                onPressed: _processing || _savedEventId != null
                    ? null
                    : _saveIncident,
                icon: const Icon(Icons.history_rounded),
                label: Text(
                  _savedEventId == null
                      ? 'Ajouter à Mon véhicule'
                      : 'Incident enregistré',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _copyGarageSummary,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copier pour le garage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(result.disclaimer, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUseAssistant = _stoppedSafe == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistance immédiate'),
        actions: [
          if (_sessionId != null)
            IconButton(
              tooltip: 'Supprimer ce dossier',
              onPressed: _processing ? null : _deleteCurrentAssistance,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          if (_sessionId != null)
            IconButton(
              tooltip: 'Nouvelle assistance',
              onPressed: _processing ? null : _newAssistance,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: ListView(
        key: const ValueKey('emergency-assistance-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AutoClair vous aide à décider quoi faire maintenant',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Voyant, bruit, panne, fumée ou comportement inhabituel : '
                    'la priorité est de savoir s’il faut s’arrêter, demander une assistance ou faire contrôler le véhicule.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _safetyStartCard(),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            AbsorbPointer(
              absorbing: !canUseAssistant || _processing,
              child: Opacity(
                opacity: canUseAssistant ? 1 : 0.55,
                child: Column(
                  children: [
                    _categoryCard(),
                    const SizedBox(height: 10),
                    _vehicleContextCard(),
                    const SizedBox(height: 10),
                    _riskChecksCard(),
                    const SizedBox(height: 10),
                    _descriptionAndMediaCard(),
                  ],
                ),
              ),
            ),
            if (canUseAssistant) ...[
              const SizedBox(height: 10),
              _localDecisionCard(),
            ],
            const SizedBox(height: 10),
            _assistanceProfileCard(),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('emergency-analyze-button'),
              onPressed: canUseAssistant && !_processing && _vehicle != null
                  ? _analyze
                  : null,
              icon: _processing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.assistant_outlined),
              label: Text(
                _processing ? 'Analyse en cours…' : 'Analyser la situation',
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              _resultCard(_result!),
            ],
          ],
        ],
      ),
    );
  }
}
