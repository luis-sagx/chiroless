import 'package:flutter/material.dart';

import '../../../../models/recurring_transaction_model.dart';

class RecurrenceFormFields extends StatelessWidget {
  const RecurrenceFormFields({
    super.key,
    required this.enabled,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.onEnabledChanged,
    required this.onFrequencyChanged,
    required this.onEndDateChanged,
  });

  final bool enabled;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<RecurrenceFrequency> onFrequencyChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  String _frequencyLabel(RecurrenceFrequency value) => switch (value) {
    RecurrenceFrequency.weekly => 'Cada semana',
    RecurrenceFrequency.monthly => 'Cada mes',
    RecurrenceFrequency.yearly => 'Cada año',
  };

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate,
      firstDate: DateTime(startDate.year, startDate.month, startDate.day),
      lastDate: DateTime(2100),
    );
    if (picked != null) onEndDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Repetir automáticamente'),
        subtitle: const Text('Se registrará al abrir la app en cada fecha.'),
        value: enabled,
        onChanged: onEnabledChanged,
      ),
      if (enabled) ...[
        DropdownButtonFormField<RecurrenceFrequency>(
          initialValue: frequency,
          decoration: const InputDecoration(labelText: 'Frecuencia'),
          items: RecurrenceFrequency.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_frequencyLabel(value)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onFrequencyChanged(value);
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                endDate == null
                    ? 'Sin fecha de finalización'
                    : 'Termina el ${endDate!.day}/${endDate!.month}/${endDate!.year}',
              ),
            ),
            TextButton(
              onPressed: () => _selectEndDate(context),
              child: Text(endDate == null ? 'Elegir fecha' : 'Cambiar'),
            ),
            if (endDate != null)
              IconButton(
                tooltip: 'Quitar fecha de finalización',
                onPressed: () => onEndDateChanged(null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ],
    ],
  );
}
