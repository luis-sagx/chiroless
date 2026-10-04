/// Borrador de transacción interpretado desde texto, voz o imagen.
/// El usuario SIEMPRE lo confirma en el QuickAddSheet antes de guardarlo.
class TransactionDraft {
  final bool isExpense;
  final double? amount;
  final String? category;
  final String description;
  final DateTime date;

  const TransactionDraft({
    required this.isExpense,
    this.amount,
    this.category,
    this.description = '',
    required this.date,
  });

  bool get isComplete => amount != null && amount! > 0 && category != null;
}
