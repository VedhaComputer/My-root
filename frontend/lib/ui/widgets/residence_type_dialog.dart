// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class PlaceRelationshipResult {
  final String residenceType;
  final String indigenousClassification;

  const PlaceRelationshipResult({
    this.residenceType = 'Permanent',
    required this.indigenousClassification,
  });

  @override
  String toString() => indigenousClassification;
}

/// Dialog prompting the user to declare explicit place-specific classification:
/// Indigenous or Non-Indigenous. No residence type prompt. No default choice.
class ResidenceTypeDialog extends StatefulWidget {
  final String placeName;
  final String? initialClassification;
  final String initialResidenceType;

  const ResidenceTypeDialog({
    super.key,
    required this.placeName,
    this.initialClassification,
    this.initialResidenceType = 'Permanent',
  });

  @override
  State<ResidenceTypeDialog> createState() => _ResidenceTypeDialogState();
}

typedef PlaceClassificationDialog = ResidenceTypeDialog;

class _ResidenceTypeDialogState extends State<ResidenceTypeDialog> {
  String? _selectedClassification;

  @override
  void initState() {
    super.initState();
    _selectedClassification = widget.initialClassification;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      key: const Key('residence_type_dialog'),
      title: Row(
        children: [
          Icon(Icons.person_pin_circle_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select Connection for ${widget.placeName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To actively select ${widget.placeName} for contributing community knowledge, please explicitly declare your place-specific classification:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Community Classification *',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A place is considered selected only after explicitly choosing Indigenous or Non-Indigenous. Classification cannot be inferred from caste, name, location, or authorization role.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              key: const Key('classification_indigenous'),
              value: 'Indigenous',
              groupValue: _selectedClassification,
              title: const Text(
                'Indigenous',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Native or indigenous lineage associated with this locality.',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (val) {
                if (val != null) setState(() => _selectedClassification = val);
              },
            ),
            RadioListTile<String>(
              key: const Key('classification_non_indigenous'),
              value: 'Non-Indigenous',
              groupValue: _selectedClassification,
              title: const Text(
                'Non-Indigenous',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Non-indigenous connection with this locality.',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (val) {
                if (val != null) setState(() => _selectedClassification = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('residence_type_cancel'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('residence_type_confirm'),
          onPressed: _selectedClassification == null
              ? null
              : () => Navigator.of(context).pop(
                    PlaceRelationshipResult(
                      indigenousClassification: _selectedClassification!,
                    ),
                  ),
          child: const Text('Confirm Selection'),
        ),
      ],
    );
  }
}
