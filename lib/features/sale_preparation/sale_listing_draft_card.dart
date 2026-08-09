import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'sale_listing_draft.dart';

class SaleListingDraftCard extends StatelessWidget {
  const SaleListingDraftCard({
    required this.draft,
    required this.onCopyTitle,
    required this.onCopyAll,
    super.key,
  });

  final SaleListingDraft draft;
  final VoidCallback onCopyTitle;
  final VoidCallback onCopyAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Brouillon de votre annonce',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'AutoClair utilise uniquement les informations déjà connues. '
            'Relisez et complétez le brouillon avant publication.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          _DraftSection(
            icon: Icons.description_outlined,
            title: 'Titre proposé',
            child: SelectableText(
              draft.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          _DraftSection(
            icon: Icons.description_outlined,
            title: 'Description',
            child: SelectableText(draft.description),
          ),
          if (draft.highlights.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ListSection(
              icon: Icons.checklist_outlined,
              title: 'Points factuels à mettre en avant',
              items: draft.highlights,
            ),
          ],
          if (draft.informationToComplete.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ListSection(
              icon: Icons.edit_outlined,
              title: 'À compléter avant publication',
              items: draft.informationToComplete,
            ),
          ],
          const SizedBox(height: 12),
          _ListSection(
            icon: Icons.photo_camera_outlined,
            title: 'Ordre conseillé des photos',
            items: draft.photoOrder,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Le brouillon ne prétend pas connaître l’état mécanique, '
                    'les équipements absents d’AutoClair ni la valeur de '
                    'marché. Aucun de ces éléments n’est inventé.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopyTitle,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copier le titre'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCopyAll,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copier l’annonce'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftSection extends StatelessWidget {
  const _DraftSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _DraftSection(
      icon: icon,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 1}. '),
                Expanded(child: Text(items[index])),
              ],
            ),
            if (index != items.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}
