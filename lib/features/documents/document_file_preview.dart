import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'selected_document_file.dart';

class DocumentFilePreview extends StatelessWidget {
  const DocumentFilePreview({
    required this.file,
    this.onRemove,
    this.onReplace,
    super.key,
  });

  final SelectedDocumentFile file;
  final VoidCallback? onRemove;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (file.isImage)
            SizedBox(
              height: 210,
              child: Image.memory(
                file.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _FileIconPreview(
                  icon: Icons.image_not_supported_outlined,
                ),
              ),
            )
          else
            const SizedBox(
              height: 150,
              child: _FileIconPreview(icon: Icons.picture_as_pdf_outlined),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Icon(
                  file.isImage
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.originalName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${file.extension.toUpperCase()} • ${file.formattedSize}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (onReplace != null)
                  TextButton.icon(
                    onPressed: onReplace,
                    icon: const Icon(Icons.swap_horiz, size: 19),
                    label: const Text('Remplacer'),
                  )
                else if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    tooltip: 'Retirer le fichier',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileIconPreview extends StatelessWidget {
  const _FileIconPreview({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.softPrimary,
      child: Center(child: Icon(icon, size: 68, color: AppColors.primary)),
    );
  }
}
