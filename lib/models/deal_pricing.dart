import 'enums.dart';

/// Расчёт стоимости сделки. Те же правила проверяет сервер (pb_hooks/lib.js),
/// поэтому клиент показывает итог и ошибки заранее, а сервер остаётся
/// последней инстанцией.
class DealPricing {
  /// Наибольшая скидка, %, по способу оплаты.
  static const discountLimit = {
    PaymentType.cash: 5.0,
    PaymentType.credit: 3.0,
    PaymentType.leasing: 2.0,
  };

  /// Зачёт старого автомобиля не больше этой доли стоимости.
  static const tradeInShare = 0.5;

  /// Первоначальный взнос по кредиту не меньше этой доли итога.
  static const downPaymentShare = 0.2;

  static const minTerm = 6;
  static const maxTerm = 84;

  /// Годовая ставка кредита.
  static const creditRate = 0.165;

  final double carPrice;
  final double servicesTotal;
  final PaymentType payment;
  final double discountPercent;
  final double tradeIn;
  final double downPayment;
  final int termMonths;

  const DealPricing({
    required this.carPrice,
    this.servicesTotal = 0,
    this.payment = PaymentType.cash,
    this.discountPercent = 0,
    this.tradeIn = 0,
    this.downPayment = 0,
    this.termMonths = 0,
  });

  double get subtotal => carPrice + servicesTotal;
  double get discountAmount => subtotal * discountPercent / 100;

  /// Итог в целых рублях.
  double get total =>
      (subtotal * (1 - discountPercent / 100) - tradeIn).roundToDouble();

  double get maxDiscount => discountLimit[payment] ?? 0;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (discountPercent > maxDiscount) {
      errors['discountPercent'] =
          'Для этого способа оплаты скидка не больше ${_fmt(maxDiscount)} %';
    }
    if (tradeIn > subtotal * tradeInShare) {
      errors['tradeInValue'] =
          'Зачёт старого автомобиля не больше половины стоимости';
    } else if (total <= 0) {
      errors['tradeInValue'] = 'Итоговая стоимость должна быть положительной';
    }
    if (payment == PaymentType.credit) {
      if (downPayment < total * downPaymentShare) {
        errors['downPayment'] = 'Первоначальный взнос не меньше 20 % стоимости';
      }
      if (termMonths < minTerm || termMonths > maxTerm) {
        errors['termMonths'] = 'Срок кредита от $minTerm до $maxTerm месяцев';
      }
    }
    return errors;
  }

  /// Ежемесячный платёж по кредиту (аннуитет); для других способов оплаты — null.
  double? get monthlyPayment {
    if (payment != PaymentType.credit || termMonths <= 0) return null;
    final principal = total - downPayment;
    if (principal <= 0) return 0;
    final r = creditRate / 12;
    final k = _pow(1 + r, termMonths);
    return principal * r * k / (k - 1);
  }

  static double _pow(double base, int n) {
    var result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= base;
    }
    return result;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
