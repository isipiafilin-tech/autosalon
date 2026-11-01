// Бизнес-правила автосалона на стороне сервера. Подключается из autosalon.pb.js.

const DISCOUNT_LIMIT = { cash: 5, credit: 3, leasing: 2 };
const TRANSITIONS = { new: ['approved', 'cancelled'], approved: ['cancelled'], signed: [], cancelled: [] };
const MAX_DRIVE_MS = 3 * 60 * 60 * 1000;

function fail(status, message, field, code) {
  const data = {};
  if (field) data[field] = new ValidationError(code || 'invalid', message);
  throw new ApiError(status, message, data);
}

function parseDate(value) {
  return new Date(String(value).replace(' ', 'T'));
}

function isClient(auth) {
  return auth && auth.getString('role') === 'client';
}

// Карточка клиента, привязанная к учётной записи (связь один к одному).
function ownCustomer(app, auth) {
  return app.findFirstRecordByData('customers', 'user', auth.id);
}

// ---------- сделки ----------

// Стоимость сделки; те же правила повторяет клиент (DealPricing в Dart).
function calcDeal(app, rec) {
  const car = app.findRecordById('cars', rec.getString('car'));
  let services = 0;
  for (const id of rec.getStringSlice('services')) {
    services += app.findRecordById('services', id).getFloat('price');
  }
  const subtotal = car.getFloat('price') + services;
  const payment = rec.getString('paymentType');
  const percent = rec.getFloat('discountPercent');
  const limit = DISCOUNT_LIMIT[payment] || 0;
  if (percent > limit) {
    fail(422, `Для этого способа оплаты скидка не больше ${limit} %`, 'discountPercent', 'discount_limit');
  }
  const tradeIn = rec.getFloat('tradeInValue');
  if (tradeIn > subtotal * 0.5) {
    fail(422, 'Зачёт старого автомобиля не больше половины стоимости', 'tradeInValue', 'trade_in_limit');
  }
  const total = Math.round(subtotal * (1 - percent / 100) - tradeIn);
  if (total <= 0) fail(422, 'Итоговая стоимость должна быть положительной', 'tradeInValue', 'total_not_positive');
  if (payment === 'credit') {
    if (rec.getFloat('downPayment') < total * 0.2) {
      fail(422, 'Первоначальный взнос не меньше 20 % стоимости', 'downPayment', 'down_payment_min');
    }
    const term = rec.getInt('termMonths');
    if (term < 6 || term > 84) fail(422, 'Срок кредита от 6 до 84 месяцев', 'termMonths', 'term_range');
  }
  return { car, total };
}

function beforeDealCreate(e) {
  const rec = e.record;
  if (isClient(e.auth)) {
    rec.set('customer', ownCustomer(e.app, e.auth).id);
    rec.set('status', 'new');
    rec.set('manager', '');
  }
  const { car, total } = calcDeal(e.app, rec);
  if (car.getString('status') !== 'available' || car.getString('deletedAt')) {
    fail(409, 'Автомобиль уже зарезервирован или продан', 'car', 'car_unavailable');
  }
  rec.set('totalPrice', total);
  return car;
}

function beforeDealUpdate(e) {
  const rec = e.record;
  const from = rec.original().getString('status');
  const to = rec.getString('status');
  if (from !== to && !TRANSITIONS[from].includes(to)) {
    fail(409, `Недопустимый переход статуса: ${from} → ${to}`, 'status', 'bad_transition');
  }
  if (to === 'approved' && !rec.getString('manager') && e.auth) rec.set('manager', e.auth.id);
  return { from, to };
}

function releaseCar(app, carId) {
  const car = app.findRecordById('cars', carId);
  if (car.getString('status') === 'reserved') {
    car.set('status', 'available');
    app.save(car);
  }
}

// ---------- договоры ----------

function beforeContractCreate(e) {
  const rec = e.record;
  const deal = e.app.findRecordById('deals', rec.getString('deal'));
  if (deal.getString('status') !== 'approved') {
    fail(409, 'Договор оформляется только по одобренной сделке', 'deal', 'deal_not_approved');
  }
  if (Math.round(rec.getFloat('amount')) !== Math.round(deal.getFloat('totalPrice'))) {
    fail(422, 'Сумма договора должна совпадать со стоимостью сделки', 'amount', 'amount_mismatch');
  }
  if (!rec.getString('number')) {
    const year = new Date().getFullYear();
    const next = e.app.countRecords('contracts') + 1;
    rec.set('number', `АС-${year}-${String(next).padStart(5, '0')}`);
  }
  return deal;
}

function afterContractCreate(app, deal) {
  deal.set('status', 'signed');
  app.save(deal);
  const car = app.findRecordById('cars', deal.getString('car'));
  car.set('status', 'sold');
  app.save(car);
}

// ---------- тест-драйвы ----------

function checkTestDrive(e, isCreate) {
  const rec = e.record;
  if (isCreate && isClient(e.auth)) {
    rec.set('customer', ownCustomer(e.app, e.auth).id);
    rec.set('status', 'planned');
  }
  if (rec.getString('status') !== 'planned') return;

  const start = parseDate(rec.getString('startsAt'));
  const end = parseDate(rec.getString('endsAt'));
  if (!(end > start)) fail(422, 'Окончание должно быть позже начала', 'endsAt', 'range');
  if (end - start > MAX_DRIVE_MS) fail(422, 'Тест-драйв не длиннее трёх часов', 'endsAt', 'too_long');
  if (isCreate && start < new Date()) fail(422, 'Время начала уже прошло', 'startsAt', 'in_past');

  const car = e.app.findRecordById('cars', rec.getString('car'));
  if (car.getString('status') === 'sold') fail(409, 'Автомобиль уже продан', 'car', 'car_sold');

  const busy = e.app.findRecordsByFilter(
    'test_drives',
    'car = {:car} && status = "planned" && deletedAt = "" && id != {:id} && startsAt < {:end} && endsAt > {:start}',
    '',
    1,
    0,
    {
      car: rec.getString('car'),
      id: rec.id,
      start: rec.getString('startsAt'),
      end: rec.getString('endsAt'),
    },
  );
  if (busy.length > 0) {
    fail(409, 'Автомобиль в это время занят другим тест-драйвом', 'startsAt', 'time_conflict');
  }
}

// ---------- пользователи ----------

function createCustomerProfile(app, user) {
  if (user.getString('role') !== 'client') return;
  const name = user.getString('name') || user.getString('email').split('@')[0];
  const rec = new Record(app.findCollectionByNameOrId('customers'));
  rec.set('user', user.id);
  rec.set('fullName', name.length >= 5 ? name : `${name} (клиент)`);
  rec.set('email', user.getString('email'));
  const phone = user.getString('phone');
  if (phone) rec.set('phone', phone);
  app.save(rec);
}

module.exports = {
  beforeDealCreate,
  beforeDealUpdate,
  releaseCar,
  beforeContractCreate,
  afterContractCreate,
  checkTestDrive,
  createCustomerProfile,
};
