// Заливка демонстрационных данных автосалона в PocketBase.
//
// Запуск:        node seed.mjs
// С очисткой:    node seed.mjs --reset
// Нужен Node.js 18+ (fetch встроен). Сервер должен быть запущен, а учётная запись
// суперпользователя создана командой:
//   pocketbase superuser upsert admin@autosalon.local Admin12345
//
// Данные создаются через API с токеном суперпользователя, поэтому серверные
// проверки из pb_hooks (стоимость сделки, резервирование, договоры) работают так же,
// как при обращении из приложения.

const BASE = process.env.API_URL ?? 'http://127.0.0.1:8090';
const SU = { identity: 'admin@autosalon.local', password: process.env.SU_PASSWORD ?? 'Admin12345' };
const RESET = process.argv.includes('--reset');

let token = '';

async function api(method, path, body) {
  const res = await fetch(`${BASE}/api${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: token },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    throw new Error(`${method} ${path} → ${res.status}: ${JSON.stringify(data)}`);
  }
  return data;
}

const create = (col, body) => api('POST', `/collections/${col}/records`, body);
const update = (col, id, body) => api('PATCH', `/collections/${col}/records/${id}`, body);

async function listAll(col) {
  const out = [];
  for (let page = 1; ; page++) {
    const r = await api('GET', `/collections/${col}/records?page=${page}&perPage=200&fields=id`);
    out.push(...r.items);
    if (page >= r.totalPages) return out;
  }
}

// ---------- детерминированный «случайный» выбор ----------
let seed = 20261101;
const rnd = () => (seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296;
const pick = (a) => a[Math.floor(rnd() * a.length)];
const between = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const sample = (a, n) => [...a].sort(() => rnd() - 0.5).slice(0, n);

const stamp = (d) => d.toISOString().replace('T', ' ');
const daysFromNow = (d, hour = 12) => {
  const t = new Date();
  t.setDate(t.getDate() + d);
  t.setUTCHours(hour, 0, 0, 0);
  return stamp(t);
};

async function main() {
  const auth = await fetch(`${BASE}/api/collections/_superusers/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(SU),
  });
  if (!auth.ok) throw new Error('Не удалось войти суперпользователем: ' + (await auth.text()));
  token = (await auth.json()).token;

  const existing = await api('GET', '/collections/brands/records?perPage=1&fields=id');
  if (existing.totalItems > 0 && !RESET) {
    console.log('Данные уже есть. Для повторной заливки запустите: node seed.mjs --reset');
    return;
  }
  if (RESET) {
    for (const col of ['contracts', 'deals', 'test_drives', 'customers', 'cars', 'car_models', 'services', 'options', 'brands', 'users']) {
      for (const r of await listAll(col)) await api('DELETE', `/collections/${col}/records/${r.id}`);
    }
    console.log('Старые данные удалены.');
  }

  // ---------- справочники ----------
  const brandRows = [
    ['Toyota', 'Япония', 1937], ['Volkswagen', 'Германия', 1937], ['BMW', 'Германия', 1916],
    ['Mercedes-Benz', 'Германия', 1926], ['Kia', 'Южная Корея', 1944], ['Hyundai', 'Южная Корея', 1967],
    ['Skoda', 'Чехия', 1895], ['Lada', 'Россия', 1966],
  ];
  const brands = {};
  for (const [name, country, foundedYear] of brandRows) {
    brands[name] = (await create('brands', { name, country, foundedYear, description: `${name}: официальный дилер, гарантия производителя.` })).id;
  }

  const modelRows = [
    ['Toyota', 'Camry', 'sedan', 5, 3400000], ['Toyota', 'RAV4', 'suv', 5, 3900000], ['Toyota', 'Corolla', 'sedan', 5, 2300000],
    ['Volkswagen', 'Polo', 'sedan', 5, 1700000], ['Volkswagen', 'Tiguan', 'suv', 5, 3600000], ['Volkswagen', 'Golf', 'hatchback', 5, 2500000],
    ['BMW', '3 Series', 'sedan', 5, 5200000], ['BMW', 'X5', 'suv', 5, 9800000],
    ['Mercedes-Benz', 'C-Class', 'sedan', 5, 6100000], ['Mercedes-Benz', 'GLC', 'suv', 5, 8200000],
    ['Kia', 'Rio', 'sedan', 5, 1600000], ['Kia', 'Sportage', 'suv', 5, 3300000],
    ['Hyundai', 'Solaris', 'sedan', 5, 1500000], ['Hyundai', 'Creta', 'suv', 5, 2400000],
    ['Skoda', 'Octavia', 'hatchback', 5, 2700000], ['Skoda', 'Kodiaq', 'suv', 7, 4300000],
    ['Lada', 'Vesta', 'sedan', 5, 1300000], ['Lada', 'Niva Travel', 'suv', 5, 1250000],
  ];
  const models = [];
  for (const [brand, name, bodyType, seats, price] of modelRows) {
    const rec = await create('car_models', { brand: brands[brand], name, bodyType, seats });
    models.push({ id: rec.id, price });
  }

  const optionRows = [
    ['Кожаный салон', 'comfort', 85000], ['Подогрев сидений', 'comfort', 25000], ['Панорамная крыша', 'comfort', 90000],
    ['Адаптивный круиз-контроль', 'safety', 70000], ['Камера кругового обзора', 'safety', 55000], ['Контроль полосы движения', 'safety', 40000],
    ['Навигационная система', 'multimedia', 35000], ['Аудиосистема премиум', 'multimedia', 60000], ['Apple CarPlay и Android Auto', 'multimedia', 15000],
    ['Литые диски 19"', 'exterior', 65000], ['Светодиодные фары', 'exterior', 45000], ['Фаркоп', 'exterior', 30000],
  ];
  const options = [];
  for (const [name, category, price] of optionRows) options.push((await create('options', { name, category, price })).id);

  const serviceRows = [
    ['КАСКО на год', 'Страхование от ущерба и угона', 95000], ['ОСАГО', 'Обязательное страхование', 12000],
    ['Защитное покрытие кузова', 'Керамика, 2 слоя', 45000], ['Антикоррозийная обработка', 'Днище и скрытые полости', 22000],
    ['Тонировка стёкол', 'Задняя полусфера', 9000], ['Сигнализация с автозапуском', 'Установка и настройка', 38000],
    ['Комплект зимней резины', 'Шины на литых дисках', 52000], ['Расширенная гарантия', 'Ещё два года', 60000],
  ];
  const services = [];
  for (const [name, description, price] of serviceRows) services.push((await create('services', { name, description, price })).id);

  // ---------- автомобили ----------
  const colors = ['Белый', 'Чёрный', 'Серый', 'Серебристый', 'Синий', 'Красный', 'Зелёный'];
  const vinChars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';
  const vin = () => Array.from({ length: 17 }, () => vinChars[Math.floor(rnd() * vinChars.length)]).join('');
  const cars = [];
  for (const m of models) {
    for (let i = 0; i < between(2, 3); i++) {
      const isNew = rnd() < 0.7;
      const year = isNew ? between(2025, 2026) : between(2021, 2024);
      const engine = pick(['petrol', 'petrol', 'diesel', 'hybrid', 'electric']);
      const rec = await create('cars', {
        model: m.id,
        vin: vin(),
        year,
        color: pick(colors),
        mileage: isNew ? 0 : between(8000, 90000),
        price: Math.round((m.price * (isNew ? 1 : 0.8) * (0.95 + rnd() * 0.15)) / 10000) * 10000,
        engine,
        transmission: pick(['automatic', 'automatic', 'robot', 'cvt', 'manual']),
        horsepower: between(90, 340),
        status: 'available',
        options: sample(options, between(0, 5)),
      });
      cars.push(rec);
    }
  }
  console.log(`Автомобилей: ${cars.length}`);

  // ---------- пользователи и клиенты ----------
  const mkUser = (email, name, role, password, phone) =>
    create('users', { email, password, passwordConfirm: password, name, role, phone, emailVisibility: true, verified: true });
  const admin = await mkUser('admin@autosalon.ru', 'Сергеев Алексей Петрович', 'admin', 'admin12345', '+7 (495) 100-20-30');
  const manager1 = await mkUser('manager@autosalon.ru', 'Козлова Марина Игоревна', 'manager', 'manager12345', '+7 (495) 100-20-31');
  const manager2 = await mkUser('manager2@autosalon.ru', 'Орлов Денис Сергеевич', 'manager', 'manager12345', '+7 (495) 100-20-32');
  const clientRows = [
    ['client@autosalon.ru', 'Иванов Пётр Сергеевич', '+7 (916) 123-45-67', 'Москва'],
    ['smirnova@example.ru', 'Смирнова Анна Викторовна', '+7 (903) 222-33-44', 'Москва'],
    ['volkov@example.ru', 'Волков Артём Андреевич', '+7 (925) 765-43-21', 'Химки'],
    ['kuznetsova@example.ru', 'Кузнецова Ольга Дмитриевна', '+7 (910) 555-66-77', 'Мытищи'],
    ['popov@example.ru', 'Попов Игорь Николаевич', '+7 (999) 101-02-03', 'Москва'],
    ['sokolova@example.ru', 'Соколова Елена Павловна', '+7 (985) 404-50-60', 'Балашиха'],
  ];
  const customers = [];
  for (const [email, name, phone, city] of clientRows) {
    const u = await mkUser(email, name, 'client', 'client12345', phone);
    // карточку клиента создал серверный хук; дополняем её данными
    const profile = (await api('GET', `/collections/customers/records?filter=${encodeURIComponent(`user="${u.id}"`)}`)).items[0];
    customers.push(await update('customers', profile.id, { phone, city, birthDate: stamp(new Date(between(1970, 2000), between(0, 11), between(1, 28))) }));
  }
  for (const [name, phone, city] of [
    ['Лебедев Максим Олегович', '+7 (905) 300-40-50', 'Москва'],
    ['Новикова Татьяна Юрьевна', '+7 (926) 811-22-33', 'Люберцы'],
    ['Морозов Владислав Игоревич', '+7 (977) 600-70-80', 'Москва'],
  ]) {
    customers.push(await create('customers', { fullName: name, phone, city }));
  }

  // ---------- сделки ----------
  const free = [...cars];
  const takeCar = () => free.splice(Math.floor(rnd() * free.length), 1)[0];
  const deal = async (customer, status, overrides = {}) => {
    const car = takeCar();
    const paymentType = overrides.paymentType ?? pick(['cash', 'credit', 'credit', 'leasing']);
    const base = { customer: customer.id, car: car.id, manager: pick([manager1, manager2]).id, services: sample(services, between(0, 3)), status: 'new', paymentType, discountPercent: paymentType === 'cash' ? between(0, 5) : paymentType === 'credit' ? between(0, 3) : between(0, 2), tradeInValue: rnd() < 0.3 ? Math.round((car.price * 0.2) / 100000) * 100000 : 0, note: '' };
    if (paymentType === 'credit') {
      base.termMonths = pick([12, 24, 36, 48, 60]);
      base.downPayment = Math.round(car.price * 0.3);
    }
    const created = await create('deals', { ...base, ...overrides });
    if (status === 'new') return created;
    if (status === 'cancelled') return update('deals', created.id, { status: 'cancelled' });
    const approved = await update('deals', created.id, { status: 'approved', manager: base.manager });
    if (status === 'approved') return approved;
    await create('contracts', { deal: created.id, signedAt: daysFromNow(-between(5, 170)), amount: approved.totalPrice, warrantyMonths: pick([12, 24, 36, 60]) });
    return approved;
  };
  const dealPlan = ['new', 'new', 'new', 'new', 'new', 'approved', 'approved', 'approved', 'signed', 'signed', 'signed', 'signed', 'signed', 'signed', 'cancelled', 'cancelled'];
  for (let i = 0; i < dealPlan.length; i++) await deal(customers[i % customers.length], dealPlan[i]);

  // ---------- тест-драйвы ----------
  const forDrives = sample(free, 8);
  const drives = [
    [0, 1, 10, 'planned'], [1, 2, 12, 'planned'], [2, 2, 15, 'planned'], [3, 3, 11, 'planned'],
    [4, 4, 14, 'planned'], [5, 5, 10, 'planned'], [0, -3, 13, 'done'], [1, -6, 16, 'done'],
  ];
  for (let i = 0; i < drives.length; i++) {
    const [ci, day, hour, status] = drives[i];
    await create('test_drives', {
      car: forDrives[i].id,
      customer: customers[ci].id,
      startsAt: daysFromNow(day, hour),
      endsAt: daysFromNow(day, hour + 1),
      status,
      comment: status === 'done' ? 'Клиент остался доволен' : '',
    });
  }

  // ---------- удалённые записи (для корзины) ----------
  const spare = free.filter((c) => !forDrives.includes(c));
  await update('cars', spare[0].id, { deletedAt: stamp(new Date()) });
  await update('options', options[11], { deletedAt: stamp(new Date()) });
  await update('customers', customers[8].id, { deletedAt: stamp(new Date()) });

  console.log('Готово. Учётные записи:');
  console.log('  администратор  admin@autosalon.ru    admin12345');
  console.log('  менеджер       manager@autosalon.ru  manager12345');
  console.log('  клиент         client@autosalon.ru   client12345');
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
