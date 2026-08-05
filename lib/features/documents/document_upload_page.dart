import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'document_analysis_journey.dart';
import 'document_analysis_service.dart';
import 'document_file_preview.dart';
import 'document_scanner_service.dart';
import 'document_type_catalog.dart';
import 'document_vehicle_selector.dart';
import 'document_upload_service.dart';
import 'selected_document_file.dart';

class DocumentUploadPage extends StatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

enum _AnalysisStage { idle, uploading, analyzing, failed }

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _vehicleService = VehicleService();
  final _uploadService = DocumentUploadService();
  final _analysisService = DocumentAnalysisService();
  final _scannerService = DocumentScannerService();

  late final DocumentAnalysisJourney _journey;

  List<Vehicle> _vehicles = const [];
  String? _selectedVehicleId;
  String _documentType = 'estimate';
  SelectedDocumentFile? _selectedFile;
  bool _loadingVehicles = true;
  bool _pickingFile = false;
  bool _scanningDocument = false;
  bool _processing = false;
  String? _loadError;
  String? _journeyError;
  String _progressMessage = '';
  _AnalysisStage _stage = _AnalysisStage.idle;

  bool get _documentAlreadyUploaded => _journey.hasUploadedDocument;

  bool get _selectingDocument => _pickingFile || _scanningDocument;

  @override
  void initState() {
    super.initState();
    _journey = DocumentAnalysisJourney(
      analyzeDocument: _analysisService.analyzeDocument,
    );
    _loadVehicles();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loadingVehicles = true;
      _loadError = null;
    });

    try {
      final vehicles = await _vehicleService.fetchVehicles().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = vehicles.isEmpty ? null : vehicles.first.id;
      });
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _loadError =
              'Le chargement prend trop de temps. Vérifiez votre connexion.',
        );
      }
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _scanDocument() async {
    if (_selectingDocument || _processing || _documentAlreadyUploaded) return;

    setState(() => _scanningDocument = true);

    try {
      final scannedDocument = await _scannerService.scanDocument();
      if (scannedDocument == null) return;

      final selectedFile = SelectedDocumentFile.fromPlatformFile(
        scannedDocument.file,
      );

      _acceptSelectedFile(selectedFile);

      if (!mounted) return;
      final pageLabel = scannedDocument.pageCount > 1
          ? '${scannedDocument.pageCount} pages'
          : '1 page';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Document numérisé : $pageLabel. Vérifiez la prévisualisation.',
          ),
        ),
      );
    } on DocumentFileValidationException catch (error) {
      if (mounted) _showError(error.message);
    } on DocumentScannerException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError("Le document n'a pas pu être numérisé.");
      }
    } finally {
      if (mounted) setState(() => _scanningDocument = false);
    }
  }

  Future<void> _pickFile() async {
    if (_selectingDocument || _processing || _documentAlreadyUploaded) return;
    setState(() => _pickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      _acceptSelectedFile(
        SelectedDocumentFile.fromPlatformFile(result.files.single),
      );
    } on DocumentFileValidationException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Impossible de sélectionner ce fichier.');
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  void _acceptSelectedFile(SelectedDocumentFile file) {
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _journeyError = null;
      _stage = _AnalysisStage.idle;
    });
  }

  Future<void> _startAnalysis() async {
    if (_processing) return;

    if (!_documentAlreadyUploaded) {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedFile == null) {
        _showError('Sélectionnez un fichier PDF, JPEG ou PNG.');
        return;
      }
      if (_selectedVehicleId == null) {
        _showError('Sélectionnez le véhicule concerné.');
        return;
      }
    }

    setState(() {
      _processing = true;
      _journeyError = null;
      _stage = _documentAlreadyUploaded
          ? _AnalysisStage.analyzing
          : _AnalysisStage.uploading;
      _progressMessage = _documentAlreadyUploaded
          ? 'Reprise de l’analyse sécurisée…'
          : 'Préparation du document…';
    });

    try {
      final result = await _journey.run(
        uploadDocument: () => _uploadService.uploadDocument(
          vehicleId: _selectedVehicleId!,
          documentType: _documentType,
          comment: _commentController.text,
          file: _selectedFile!,
          onProgress: (message) {
            if (mounted) setState(() => _progressMessage = message);
          },
        ),
        onAnalysisStarted: (_) {
          if (!mounted) return;
          setState(() {
            _stage = _AnalysisStage.analyzing;
            _progressMessage =
                'AutoClair lit le document et prépare votre synthèse…';
          });
        },
      );

      if (mounted) {
        context.go('/history/${result.documentId}/analysis');
      }
    } on DocumentUploadException catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _AnalysisStage.idle;
        _journeyError = error.message;
      });
      _showError(error.message);
    } on DocumentAnalysisException catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _AnalysisStage.failed;
        _journeyError = error.message;
      });
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _progressMessage = '';
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyser un document'),
        actions: [
          if (_documentAlreadyUploaded && !_processing)
            IconButton(
              onPressed: () => context.go('/history'),
              icon: const Icon(Icons.history_outlined),
              tooltip: 'Voir l’historique',
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingVehicles) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: const [
          _JourneyHeader(),
          SizedBox(height: 24),
          _LoadingVehiclesCard(),
        ],
      );
    }
    if (_loadError != null) {
      return _CenteredMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Impossible de charger vos véhicules',
        message: _loadError!,
        buttonLabel: 'Réessayer',
        onPressed: _loadVehicles,
      );
    }
    if (_vehicles.isEmpty) {
      return _CenteredMessage(
        icon: Icons.directions_car_outlined,
        title: 'Ajoutez d’abord un véhicule',
        message: 'Chaque document doit être rattaché au véhicule concerné.',
        buttonLabel: 'Ajouter un véhicule',
        onPressed: () async {
          final changed = await context.push<bool>('/vehicles/new');
          if (changed == true) await _loadVehicles();
        },
      );
    }
    if (_processing) {
      return _ProcessingView(
        stage: _stage,
        message: _progressMessage,
        fileName: _selectedFile?.originalName,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          const _JourneyHeader(),
          const SizedBox(height: 24),
          if (_journeyError != null) ...[
            _JourneyErrorCard(
              message: _journeyError!,
              documentUploaded: _documentAlreadyUploaded,
            ),
            const SizedBox(height: 18),
          ],
          Text(
            '1. Informations du document',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DocumentVehicleSelector(
            vehicles: _vehicles,
            selectedVehicleId: _selectedVehicleId,
            enabled: !_documentAlreadyUploaded,
            onChanged: (value) {
              setState(() => _selectedVehicleId = value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _documentType,
            decoration: const InputDecoration(
              labelText: 'Type de document',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            items: DocumentTypeCatalog.definitions
                .map(
                  (definition) => DropdownMenuItem(
                    value: definition.value,
                    child: Row(
                      children: [
                        Icon(definition.icon, size: 20),
                        const SizedBox(width: 10),
                        Text(definition.label),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _documentAlreadyUploaded
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _documentType = value);
                    }
                  },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _commentController,
            enabled: !_documentAlreadyUploaded,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            inputFormatters: [LengthLimitingTextInputFormatter(2000)],
            decoration: const InputDecoration(
              labelText: 'Commentaire facultatif',
              hintText: 'Ex. Le garage me conseille de remplacer les freins.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '2. Prévisualisation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            'Vérifiez le document avant de lancer son analyse.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (_selectedFile == null)
            _DocumentSourcePicker(
              scannerAvailable: _scannerService.isAvailable,
              pickingFile: _pickingFile,
              scanningDocument: _scanningDocument,
              onScan: _scanDocument,
              onBrowse: _pickFile,
            )
          else
            DocumentFilePreview(
              file: _selectedFile!,
              onReplace: _documentAlreadyUploaded ? null : _pickFile,
              onRemove: _documentAlreadyUploaded
                  ? null
                  : () => setState(() => _selectedFile = null),
            ),
          const SizedBox(height: 18),
          const _SecurityNotice(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _startAnalysis,
            icon: Icon(
              _stage == _AnalysisStage.failed
                  ? Icons.refresh_rounded
                  : Icons.auto_awesome_outlined,
            ),
            label: Text(
              _stage == _AnalysisStage.failed
                  ? 'Relancer l’analyse'
                  : 'Lancer l’analyse',
            ),
          ),
          if (_documentAlreadyUploaded) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => context.go('/history'),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Retrouver le document dans l’historique'),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'L’analyse fournit une aide informative. Elle ne remplace pas '
            'un diagnostic mécanique ou une expertise professionnelle.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoadingVehiclesCard extends StatelessWidget {
  const _LoadingVehiclesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Chargement de vos véhicules…')),
        ],
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 14),
          Text(
            'Un parcours simple, du document au résultat',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 7),
          Text(
            'Scannez ou choisissez un fichier, contrôlez sa prévisualisation, '
            'puis confirmez. Le bon résultat s’ouvrira automatiquement.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentSourcePicker extends StatelessWidget {
  const _DocumentSourcePicker({
    required this.scannerAvailable,
    required this.pickingFile,
    required this.scanningDocument,
    required this.onScan,
    required this.onBrowse,
  });

  final bool scannerAvailable;
  final bool pickingFile;
  final bool scanningDocument;
  final VoidCallback onScan;
  final VoidCallback onBrowse;

  bool get _selectingDocument => pickingFile || scanningDocument;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              scannerAvailable
                  ? Icons.document_scanner_outlined
                  : Icons.upload_file_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            scannerAvailable
                ? 'Scannez ou sélectionnez votre document'
                : 'Sélectionnez votre document',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            scannerAvailable
                ? 'Jusqu’à 10 pages • PDF généré automatiquement'
                : 'PDF, JPEG ou PNG • 15 Mo maximum',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (scannerAvailable) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selectingDocument ? null : onScan,
              icon: scanningDocument
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(
                scanningDocument
                    ? 'Préparation du scanner…'
                    : "Scanner avec l’appareil photo",
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _selectingDocument ? null : onBrowse,
            icon: pickingFile
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined),
            label: Text(
              pickingFile
                  ? 'Ouverture des fichiers…'
                  : 'Choisir un fichier existant',
            ),
          ),
          if (scannerAvailable) ...[
            const SizedBox(height: 10),
            Text(
              'Le fichier numérisé sera vérifié avant tout envoi.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({
    required this.stage,
    required this.message,
    required this.fileName,
  });

  final _AnalysisStage stage;
  final String message;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final analyzing = stage == _AnalysisStage.analyzing;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(27),
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 24),
              Text(
                analyzing ? 'Analyse en cours' : 'Envoi sécurisé du document',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (fileName != null) ...[
                const SizedBox(height: 10),
                Text(
                  fileName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 26),
              _ProgressStep(
                icon: Icons.lock_outline,
                label: 'Envoi dans le stockage privé',
                completed: analyzing,
                active: !analyzing,
              ),
              const SizedBox(height: 10),
              _ProgressStep(
                icon: Icons.auto_awesome_outlined,
                label: 'Lecture et analyse du contenu',
                completed: false,
                active: analyzing,
              ),
              const SizedBox(height: 18),
              Text(
                'Gardez cette page ouverte. Le résultat s’affichera '
                'automatiquement dès qu’il sera prêt.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.icon,
    required this.label,
    required this.completed,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? AppColors.success
        : active
        ? AppColors.primary
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.successSoft
            : active
            ? AppColors.softPrimary
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active || completed
              ? color.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(completed ? Icons.check_circle : icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyErrorCard extends StatelessWidget {
  const _JourneyErrorCard({
    required this.message,
    required this.documentUploaded,
  });

  final String message;
  final bool documentUploaded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documentUploaded
                      ? 'Le document est bien enregistré'
                      : 'Le document n’a pas été envoyé',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                if (documentUploaded) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Une nouvelle tentative réutilisera ce même document.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
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

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: AppColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Le fichier est envoyé dans votre stockage privé, sans URL '
              'publique, puis analysé pour votre compte uniquement.',
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.softPrimary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
