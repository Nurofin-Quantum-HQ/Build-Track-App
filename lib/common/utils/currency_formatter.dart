double? parseAmount(String input) {
  final cleaned = input.replaceAll('₹', '').replaceAll(',', '').trim();
  return double.tryParse(cleaned);
}
String formatCurrency(num amount) {
  if (amount == 0) return '₹0.00';
  final bool isNegative = amount < 0;
  final num absAmount = amount.abs();
  final String prefix = isNegative ? '-₹' : '₹';

  if (absAmount >= 10000000) {
    return '$prefix${(absAmount / 10000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}Cr';
  }
  if (absAmount >= 100000) {
    return '$prefix${(absAmount / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
  }
  if (absAmount >= 1000) {
    return '$prefix${(absAmount / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
  }
  if (absAmount == absAmount.toInt()) {
    return '$prefix${absAmount.toInt()}';
  } else {
    return '$prefix${absAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}';
  }
}
