import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'document_file_preview.dart';
import 'document_upload_service.dart';
import 'selected_document_file.dart';

class DocumentUploadPage extends StatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  static const _documentTypes = <String, String>{
    'estimate': 'Devis',
    'invoice': 'Facture',
    'repair_order': 'Ordre de réparation',
  };

  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _vehicleService = VehicleService();
  final _uploadService = DocumentUploadService();

  List<Vehicle> _vehicles = const [];
  String? _selectedVehicleId;
  String _documentType = 'estimate';
  SelectedDocumentFile? _selectedFile;

  bool _loadingVehicles = true;
  bool _pickingFile = false;
  bool _uploading = false;
  String? _loadError;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
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
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = vehicles.isEmpty ? null : vehicles.first.id;
      });
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _pickFile() async {
    if (_pickingFile || _uploading) return;
    setState(() => _pickingFile = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final selected = SelectedDocumentFile.fromPlatformFile(
        result.files.single,
      );

      if (mounted) setState(() => _selectedFile = selected);
    } on DocumentFileValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le fichier n'a pas pu être sélectionné."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  Future<void> _upload() async {
    if (_uploading || !_formKey.currentState!.validate()) return;

    final file = _selectedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez un fichier PDF, JPEG ou PNG.'),
        ),
      );
      return;
    }

    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez le véhicule concerné.')),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _progressMessage = 'Préparation du document…';
    });

    try {
      await _uploadService.uploadDocument(
        vehicleId: vehicleId,
        documentType: _documentType,
        comment: _commentController.text,
        file: file,
        onProgress: (message) {
          if (mounted) setState(() => _progressMessage = message);
        },
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.primary,
              size: 42,
            ),
            title: const Text('Document enregistré'),
            content: const Text(
              'Votre fichier a été transmis dans le stockage privé '
              "d'AutoClair. L'analyse sera ajoutée à la prochaine étape.",
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Terminer'),
              ),
            ],
          );
        },
      );

      if (mounted) context.go('/home');
    } on DocumentUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progressMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un document')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingVehicles) {
      return const Center(child: CircularProgressIndicator());
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

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          Text(
            'Informations du document',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedVehicleId,
            decoration: const InputDecoration(
              labelText: 'Véhicule concerné',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            items: _vehicles
                .map(
                  (vehicle) => DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(
                      '${vehicle.displayName} — ${vehicle.makeAndModel}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            validator: (value) =>
                value == null ? 'Sélectionnez le véhicule concerné.' : null,
            onChanged: _uploading
                ? null
                : (value) => setState(() => _selectedVehicleId = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _documentType,
            decoration: const InputDecoration(
              labelText: 'Type de document',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            items: _documentTypes.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(growable: false),
            onChanged: _uploading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _documentType = value);
                    }
                  },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commentController,
            enabled: !_uploading,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            inputFormatters: [LengthLimitingTextInputFormatter(2000)],
            decoration: const InputDecoration(
              labelText: 'Commentaire',
              hintText: 'Ex. Le garage me conseille de remplacer les freins.',
              alignLabelWithHint: true,
              helperText: 'Facultatif',
            ),
          ),
          const SizedBox(height: 24),
          Text('Fichier', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Formats acceptés : PDF, JPEG et PNG. Taille maximale : 15 Mo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (_selectedFile == null)
            OutlinedButton.icon(
              onPressed: _pickingFile || _uploading ? null : _pickFile,
              icon: _pickingFile
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                _pickingFile
                    ? 'Ouverture des fichiers…'
                    : 'Sélectionner un fichier',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
              ),
            )
          else
            DocumentFilePreview(
              file: _selectedFile!,
              onRemove: _uploading
                  ? () {}
                  : () => setState(() => _selectedFile = null),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Le fichier est envoyé dans un espace privé. '
                    'Il ne reçoit aucune URL publique.',
                  ),
                ),
              ],
            ),
          ),
          if (_uploading) ...[
            const SizedBox(height: 22),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              _progressMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: const Icon(Icons.lock_outline),
            label: Text(_uploading ? 'Envoi en cours…' : 'Envoyer le document'),
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
