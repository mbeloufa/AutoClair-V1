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
    if (_analyzingDocumentId != null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            onPressed: _loading || _analyzingDocumentId != null
                ? null
                : _loadDocuments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: _buildBody(context),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
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
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 90),
          const Icon(
            Icons.history_outlined,
            size: 62,
            color: AppColors.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Aucun document',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Les documents transmis apparaîtront ici.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: () => context.push('/documents/new'),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un document'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      itemCount: _documents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final document = _documents[index];
        final analyzing = _analyzingDocumentId == document.id;

        return _DocumentCard(
          document: document,
          analyzing: analyzing,
          blockedByAnotherAnalysis: _analyzingDocumentId != null && !analyzing,
          onAnalyze: () => _startAnalysis(document),
          onView: () => context.push('/history/${document.id}/analysis'),
        );
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.analyzing,
    required this.blockedByAnotherAnalysis,
    required this.onAnalyze,
    required this.onView,
  });

  final DocumentHistoryItem document;
  final bool analyzing;
  final bool blockedByAnotherAnalysis;
  final VoidCallback onAnalyze;
  final VoidCallback onView;

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
              _StatusChip(document: document),
            ],
          ),
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
          const SizedBox(height: 18),
          if (document.isCompleted)
            FilledButton.icon(
              onPressed: blockedByAnotherAnalysis ? null : onView,
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
              onPressed: analyzing || blockedByAnotherAnalysis
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
    final icon = switch (document.status) {
      'completed' => Icons.check_circle_outline,
      'processing' => Icons.hourglass_top,
      'failed' => Icons.refresh,
      _ => Icons.schedule,
    };

    return Tooltip(
      message: document.statusLabel,
      child: Icon(icon, color: AppColors.primary),
    );
  }
}
