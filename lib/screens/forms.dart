import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/format.dart';
import '../models/deal_pricing.dart';
import '../models/entities.dart';
import '../models/enums.dart';
import '../models/list_query.dart';
import '../models/permissions.dart';
import '../models/schedule.dart';
import '../repositories/repos.dart';
import '../state/auth_notifier.dart';
import '../state/lookup_notifier.dart';
import '../validation/validators.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/connection_widgets.dart';
import '../widgets/form_fields.dart';
import '../widgets/form_page.dart';

num _num(Object? v) {
  if (v is num) return v;
  return num.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
}

/// Заявка клиента или сделка сотрудника с расчётом стоимости «на лету».
/// Те же правила повторяет сервер; ошибки расчёта показываются у полей.
class DealFormScreen extends StatefulWidget {
  final bool client;
  final String? presetCar;

  const DealFormScreen({super.key, required this.client, this.presetCar});

  @override
  State<DealFormScreen> createState() => _DealFormScreenState();
}

class _DealFormScreenState extends State<DealFormScreen> {
  late final FormController _form = FormController({
    'car': widget.presetCar ?? '',
    'paymentType': PaymentType.cash.value,
    'discountPercent': '0',
    'tradeInValue': '0',
    'downPayment': '0',
    'termMonths': '0',
  })..addListener(_changed);

  Car? _car;
  String _carId = '';
  Map<String, double> _servicePrices = {};

  @override
  void initState() {
    super.initState();
    _loadServices();
    _changed();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final page = await context.read<Repos>().services.list(
        const ListQuery(perPage: 100),
      );
      if (mounted) {
        setState(
          () => _servicePrices = {for (final s in page.items) s.id: s.price},
        );
      }
    } on ApiException {
      // стоимость услуг не подгрузилась: итог пересчитается при повторном открытии
    }
  }

  Future<void> _changed() async {
    final id = '${_form.values['car'] ?? ''}';
    if (id != _carId) {
      _carId = id;
      if (id.isEmpty) {
        setState(() => _car = null);
      } else {
        try {
          final car = await context.read<Repos>().cars.get(id);
          if (mounted && _carId == id) setState(() => _car = car);
        } on ApiException {
          // автомобиль недоступен: расчёт останется без него
        }
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  DealPricing get _pricing {
    final ids = [
      for (final x in (_form.values['services'] as List? ?? const [])) '$x',
    ];
    return DealPricing(
      carPrice: _car?.price ?? 0,
      servicesTotal: ids.fold(0.0, (a, id) => a + (_servicePrices[id] ?? 0)),
      payment: parseEnum(
        PaymentType.values,
        '${_form.values['paymentType']}',
        PaymentType.cash,
      ),
      discountPercent: _num(_form.values['discountPercent']).toDouble(),
      tradeIn: _num(_form.values['tradeInValue']).toDouble(),
      downPayment: _num(_form.values['downPayment']).toDouble(),
      termMonths: _num(_form.values['termMonths']).round(),
    );
  }

  List<FieldSpec> get _fields {
    final credit = _pricing.payment == PaymentType.credit;
    return [
      if (!widget.client)
        const FieldSpec(
          'customer',
          'Клиент',
          FieldKind.relation,
          required: true,
          lookup: 'customers',
        ),
      const FieldSpec(
        'car',
        'Автомобиль',
        FieldKind.relation,
        required: true,
        lookup: 'carsFree',
      ),
      const FieldSpec(
        'services',
        'Дополнительные услуги',
        FieldKind.relationMulti,
        lookup: 'services',
      ),
      FieldSpec(
        'paymentType',
        'Способ оплаты',
        FieldKind.select,
        required: true,
        options: optionsOf(PaymentType.values),
      ),
      FieldSpec(
        'discountPercent',
        'Скидка, %',
        FieldKind.decimal,
        validators: [numRange(0, 30)],
      ),
      FieldSpec(
        'tradeInValue',
        'Зачёт старого автомобиля, ₽',
        FieldKind.integer,
        validators: [intRange(0, 100000000)],
      ),
      if (credit) ...[
        FieldSpec(
          'downPayment',
          'Первоначальный взнос, ₽',
          FieldKind.integer,
          required: true,
          validators: [intRange(0, 100000000)],
        ),
        FieldSpec(
          'termMonths',
          'Срок кредита, мес.',
          FieldKind.integer,
          required: true,
          validators: [intRange(0, 84)],
        ),
      ],
      FieldSpec(
        'note',
        'Примечание',
        FieldKind.multiline,
        validators: [maxLength(500)],
      ),
    ];
  }

  Future<void> _save(Map<String, dynamic> json) async {
    final auth = context.read<AuthNotifier>();
    final repos = context.read<Repos>();
    final body = {
      ...json,
      'status': DealStatus.newDeal.value,
      if (!widget.client && auth.role == Role.manager) 'manager': auth.user!.id,
    };
    if (widget.client) body.remove('customer');
    await repos.deals.create(body);
    if (mounted) context.read<LookupNotifier>().invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final p = _pricing;
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      ('Автомобиль', money(p.carPrice)),
      if (p.servicesTotal > 0) ('Услуги', money(p.servicesTotal)),
      if (p.discountAmount > 0) ('Скидка', '−${money(p.discountAmount)}'),
      if (p.tradeIn > 0) ('Зачёт', '−${money(p.tradeIn)}'),
    ];
    final monthly = p.monthlyPayment;
    return AppScaffold(
      title: widget.client ? 'Заявка на автомобиль' : 'Новая сделка',
      body: FormPage(
        controller: _form,
        fields: _fields,
        onSave: _save,
        localErrors: () => _car == null ? const {} : p.validate(),
        saveLabel: widget.client ? 'Отправить заявку' : 'Создать сделку',
        savedMessage: widget.client ? 'Заявка отправлена' : 'Сделка создана',
        after: Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Расчёт стоимости',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(label), Text(value)],
                    ),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Итого',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _car == null ? '—' : money(p.total),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (monthly != null && _car != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Платёж по кредиту: ${money(monthly)} в месяц '
                      '(ставка ${(DealPricing.creditRate * 100).toStringAsFixed(1)} % годовых)',
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Скидка не больше ${p.maxDiscount.round()} % для выбранной оплаты. '
                  'Окончательную сумму рассчитывает сервер.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Запись на тест-драйв (клиент) или планирование (сотрудник).
class TestDriveFormScreen extends StatefulWidget {
  final bool client;
  final String? presetCar;
  final String? id;

  const TestDriveFormScreen({
    super.key,
    required this.client,
    this.presetCar,
    this.id,
  });

  @override
  State<TestDriveFormScreen> createState() => _TestDriveFormScreenState();
}

class _TestDriveFormScreenState extends State<TestDriveFormScreen> {
  FormController? _form;
  late Future<void> _loading = _init();

  bool get _isNew => widget.id == null;

  Future<void> _init() async {
    if (_isNew) {
      final start = DateTime.now().add(const Duration(days: 1));
      final at = DateTime(start.year, start.month, start.day, 10);
      _form = FormController({
        'car': widget.presetCar ?? '',
        'startsAt': at,
        'endsAt': at.add(const Duration(hours: 1)),
        'status': DriveStatus.planned.value,
      });
      return;
    }
    final d = await context.read<Repos>().testDrives.get(widget.id!);
    _form = FormController(d.toFormValues());
  }

  List<FieldSpec> get _fields => [
    FieldSpec(
      'car',
      'Автомобиль',
      FieldKind.relation,
      required: true,
      lookup: _isNew ? 'carsFree' : 'cars',
    ),
    if (!widget.client)
      const FieldSpec(
        'customer',
        'Клиент',
        FieldKind.relation,
        required: true,
        lookup: 'customers',
      ),
    const FieldSpec('startsAt', 'Начало', FieldKind.dateTime, required: true),
    const FieldSpec('endsAt', 'Окончание', FieldKind.dateTime, required: true),
    if (!widget.client && !_isNew)
      FieldSpec(
        'status',
        'Статус',
        FieldKind.select,
        required: true,
        options: optionsOf(DriveStatus.values),
      ),
    FieldSpec(
      'comment',
      'Комментарий',
      FieldKind.multiline,
      validators: [maxLength(300)],
    ),
  ];

  Map<String, String> _localErrors() {
    final start = _form!.values['startsAt'];
    final end = _form!.values['endsAt'];
    if (start is! DateTime || end is! DateTime) return const {};
    if ('${_form!.values['status']}' != DriveStatus.planned.value) {
      return const {};
    }
    final error = validateInterval(start, end);
    if (error == null) return const {};
    return {error.contains('Время начала') ? 'startsAt' : 'endsAt': error};
  }

  Future<void> _save(Map<String, dynamic> json) async {
    final repo = context.read<Repos>().testDrives;
    final body = {...json};
    if (widget.client) body.remove('customer');
    if (_isNew) {
      await repo.create({...body, 'status': DriveStatus.planned.value});
    } else {
      await repo.update(widget.id!, body);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isNew ? 'Запись на тест-драйв' : 'Изменение тест-драйва',
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return RetryMessage(
              text: snap.error is ApiException
                  ? (snap.error as ApiException).message
                  : 'Не удалось загрузить запись.',
              onRetry: () => setState(() => _loading = _init()),
            );
          }
          return FormPage(
            controller: _form!,
            fields: _fields,
            onSave: _save,
            localErrors: _localErrors,
            saveLabel: _isNew ? 'Записаться' : 'Сохранить',
            savedMessage: _isNew
                ? 'Тест-драйв запланирован'
                : 'Изменения сохранены',
            before: const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Тест-драйв длится не более трёх часов. Автомобиль не может участвовать в двух тест-драйвах одновременно.',
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Оформление договора по одобренной сделке.
class ContractFormScreen extends StatefulWidget {
  final String? presetDeal;

  const ContractFormScreen({super.key, this.presetDeal});

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  late final FormController _form = FormController({
    'deal': widget.presetDeal ?? '',
    'signedAt': DateTime.now(),
    'warrantyMonths': '24',
  })..addListener(_dealChanged);
  String _deal = '';

  @override
  void initState() {
    super.initState();
    _dealChanged();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  // При выборе сделки сумма договора подставляется из сделки.
  Future<void> _dealChanged() async {
    final id = '${_form.values['deal'] ?? ''}';
    if (id == _deal) return;
    _deal = id;
    if (id.isEmpty) return;
    try {
      final deal = await context.read<Repos>().deals.get(id);
      if (mounted && _deal == id) _form.set('amount', deal.totalPrice.round());
    } on ApiException {
      // сумму можно ввести вручную; сервер проверит её
    }
  }

  static const _fields = [
    FieldSpec(
      'deal',
      'Сделка',
      FieldKind.relation,
      required: true,
      lookup: 'dealsApproved',
    ),
    FieldSpec(
      'number',
      'Номер договора',
      FieldKind.text,
      hint: 'Если пусто — присваивается автоматически',
    ),
    FieldSpec('signedAt', 'Дата подписания', FieldKind.date, required: true),
    FieldSpec('amount', 'Сумма, ₽', FieldKind.integer, required: true),
    FieldSpec('warrantyMonths', 'Гарантия, мес.', FieldKind.integer),
  ];

  Future<void> _save(Map<String, dynamic> json) async {
    await context.read<Repos>().contracts.create(json);
    if (mounted) context.read<LookupNotifier>().invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return AppScaffold(
      title: 'Новый договор',
      body: auth.can(Permission.manageContracts)
          ? FormPage(
              controller: _form,
              fields: _fields,
              onSave: _save,
              saveLabel: 'Оформить договор',
              savedMessage: 'Договор оформлен',
            )
          : const SizedBox.shrink(),
    );
  }
}
