import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../documents/document_analysis_service.dart';
import '../documents/document_history_item.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _service = DocumentAnalysisService();

  List<DocumentHistoryItem> _documents = const [];
  bool _loading = true;
  String? _errorMessage;
  String? _analyzingDocumentId;
  String? _deletingDocumentId;

  bool get _operationInProgress =>
      _analyzingDocumentId != null || _deletingDocumentId != null;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final documents = await _service.fetchDocuments();
      if (mounted) {
        setState(() => _documents = documents);
      }
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

  Future<void> _startAnalysis(DocumentHistoryItem document) async {
    if (_operationInProgress) {
      return;
    }

    setState(() => _analyzingDocumentId = document.id);

    try {
      final result = await _service.analyzeDocument(document.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyse terminée avec succès.')),
      );

      await _loadDocuments();

      if (mounted) {
        context.push('/history/${result.documentId}/analysis');
      }
    } on DocumentAnalysisException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          duration: const Duration(seconds: 7),
        ),
      );

      await _loadDocuments();
    } finally {
      if (mounted) {
        setState(() => _analyzingDocumentId = null);
      }
    }
  }

  Future<void> _requestDeletion(DocumentHistoryItem document) async {
    if (_operationInProgress || !document.canDelete) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_forever_outlined,
            color: AppColors.primary,
            size: 42,
          ),
          title: const Text('Supprimer ce document ?'),
          content: Text(
            'Le ${document.typeLabel.toLowerCase()}, son fichier privé '
            "et son analyse seront définitivement supprimés.\n\n"
            'Cette action est irréversible.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer définitivement'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deletingDocumentId = document.id);

    try {
      await _service.deleteDocument(document.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _documents = _documents
            .where((item) => item.id != document.id)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le document a été supprimé.')),
      );
    } on DocumentAnalysisException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingDocumentId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes documents'),
        actions: [
          IconButton(
            onPressed: _operationInProgress
                ? null
                : () => context.push('/documents/new'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Ajouter un document',
          ),
          IconButton(
            onPressed: _loading || _operationInProgress ? null : _loadDocuments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: _buildBody(context),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _documents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: AppColors.primary,
          ),
          const SizedBox(height: 18),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              onPressed: _loadDocuments,
              child: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }

    if (_documents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppColors.softPrimary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.manage_search_outlined,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Votre espace documents est prêt',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 9),
                Text(
                  'Vos devis, factures et autres documents apparaîtront ici, '
                  'dans l’ordre du plus récent au plus ancien.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => context.push('/documents/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Analyser mon premier document'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      itemCount: _documents.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HistoryHeader(documentCount: _documents.length);
        }

        final document = _documents[index - 1];
        final analyzing = _analyzingDocumentId == document.id;
        final deleting = _deletingDocumentId == document.id;
        final blockedByAnotherOperation =
            _operationInProgress && !analyzing && !deleting;

        return _DocumentCard(
          document: document,
          analyzing: analyzing,
          deleting: deleting,
          blockedByAnotherOperation: blockedByAnotherOperation,
          onAnalyze: () => _startAnalysis(document),
          onView: () => context.push('/history/${document.id}/analysis'),
          onDelete: () => _requestDeletion(document),
        );
      },
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.documentCount});

  final int documentCount;

  @override
  Widget build(BuildContext context) {
    final label = documentCount > 1 ? 'documents suivis' : 'document suivi';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.folder_copy_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$documentCount $label',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  'Retrouvez chaque fichier, son analyse et son état au même endroit.',
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.analyzing,
    required this.deleting,
    required this.blockedByAnotherOperation,
    required this.onAnalyze,
    required this.onView,
    required this.onDelete,
  });

  final DocumentHistoryItem document;
  final bool analyzing;
  final bool deleting;
  final bool blockedByAnotherOperation;
  final VoidCallback onAnalyze;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date =
        '${document.createdAt.day.toString().padLeft(2, '0')}/'
        '${document.createdAt.month.toString().padLeft(2, '0')}/'
        '${document.createdAt.year}';

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.typeLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ajouté le $date',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled:
                    document.canDelete &&
                    !analyzing &&
                    !deleting &&
                    !blockedByAnotherOperation,
                tooltip: 'Actions du document',
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('Supprimer'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusChip(document: document),
          if (document.comment != null) ...[
            const SizedBox(height: 14),
            Text(
              document.comment!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (analyzing) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text(
              'AutoClair lit le document et prépare une synthèse. '
              'Cette opération peut prendre environ une minute.',
              textAlign: TextAlign.center,
            ),
          ],
          if (deleting) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text(
              'Suppression définitive du fichier et de ses données…',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          if (document.isCompleted)
            FilledButton.icon(
              onPressed: blockedByAnotherOperation || deleting ? null : onView,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text("Voir l'analyse"),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            )
          else if (document.isProcessing)
            OutlinedButton.icon(
              onPressed: null,
              icon: const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: const Text('Analyse en cours'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            )
          else if (document.canStartAnalysis)
            FilledButton.icon(
              onPressed: analyzing || deleting || blockedByAnotherOperation
                  ? null
                  : onAnalyze,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                document.status == 'failed'
                    ? "Relancer l'analyse"
                    : 'Analyser ce document',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.document});

  final DocumentHistoryItem document;

  @override
  Widget build(BuildContext context) {
    final (icon, foreground, background) = switch (document.status) {
      'completed' => (
        Icons.check_circle_outline,
        AppColors.success,
        AppColors.successSoft,
      ),
      'processing' || 'queued' => (
        Icons.hourglass_top_rounded,
        AppColors.info,
        AppColors.infoSoft,
      ),
      'failed' => (Icons.refresh_rounded, AppColors.error, AppColors.errorSoft),
      _ => (Icons.schedule_rounded, AppColors.warning, AppColors.warningSoft),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 17),
            const SizedBox(width: 7),
            Text(
              document.statusLabel,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
