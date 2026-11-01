/// <reference path="../pb_data/types.d.ts" />
// Схема базы данных «Автосалон»: коллекции, связи, индексы и правила доступа.
// Применяется автоматически при запуске `pocketbase serve`.

migrate(
  (app) => {
    // ---------- правила доступа ----------
    const ROLE = '@request.auth.role';
    const AUTH = '@request.auth.id != ""';
    const ADMIN = `${ROLE} = "admin"`;
    const STAFF = `(${ROLE} = "manager" || ${ROLE} = "admin")`;
    // Удалённые записи (deletedAt заполнено) видит только администратор.
    const LIVE = '(deletedAt = "" || ' + ADMIN + ')';
    // Не-администратор может только пометить запись удалённой, но не снять пометку.
    const SOFT =
      '(@request.body.deletedAt:isset = false || @request.body.deletedAt != "" || ' + ADMIN + ')';

    // ---------- вспомогательные описания полей ----------
    const txt = (name, o = {}) => ({ type: 'text', name, ...o });
    const num = (name, o = {}) => ({ type: 'number', name, ...o });
    const sel = (name, values, o = {}) => ({ type: 'select', name, values, maxSelect: 1, ...o });
    const dt = (name, o = {}) => ({ type: 'date', name, ...o });
    const rel = (name, collection, o = {}) => ({
      type: 'relation',
      name,
      collectionId: app.findCollectionByNameOrId(collection).id,
      maxSelect: 1,
      cascadeDelete: false,
      ...o,
    });
    const stamps = () => [
      { type: 'autodate', name: 'created', onCreate: true, onUpdate: false },
      { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
    ];
    const make = (name, fields, rules, indexes = []) => {
      const c = new Collection({
        type: 'base',
        name,
        listRule: rules.list,
        viewRule: rules.view ?? rules.list,
        createRule: rules.create,
        updateRule: rules.update,
        deleteRule: rules.delete,
        fields: [...fields, ...stamps()],
        indexes,
      });
      app.save(c);
    };

    // ---------- пользователи (коллекция аутентификации) ----------
    const users = app.findCollectionByNameOrId('users');
    users.fields.add(
      new SelectField({
        name: 'role',
        required: true,
        maxSelect: 1,
        values: ['client', 'manager', 'admin'],
      }),
    );
    users.fields.add(new TextField({ name: 'phone', max: 20 }));
    users.listRule = `id = @request.auth.id || ${STAFF}`;
    users.viewRule = `id = @request.auth.id || ${STAFF}`;
    // Самостоятельно можно зарегистрироваться только клиентом.
    users.createRule = `(@request.auth.id = "" && @request.body.role = "client") || ${ADMIN}`;
    users.updateRule = `(id = @request.auth.id && @request.body.role:isset = false) || ${ADMIN}`;
    users.deleteRule = ADMIN;
    app.save(users);

    // ---------- справочники ----------
    make(
      'brands',
      [
        txt('name', { required: true, min: 2, max: 60 }),
        txt('country', { required: true, min: 2, max: 60 }),
        num('foundedYear', { min: 1850, max: 2100, onlyInt: true }),
        txt('description', { max: 500 }),
        dt('deletedAt'),
      ],
      { list: `${AUTH} && ${LIVE}`, create: ADMIN, update: `${ADMIN}`, delete: ADMIN },
      ['CREATE UNIQUE INDEX idx_brands_name ON brands (name)'],
    );

    make(
      'options',
      [
        txt('name', { required: true, min: 2, max: 80 }),
        sel('category', ['comfort', 'safety', 'multimedia', 'exterior'], { required: true }),
        num('price', { required: true, min: 0, max: 5000000 }),
        dt('deletedAt'),
      ],
      { list: `${AUTH} && ${LIVE}`, create: ADMIN, update: ADMIN, delete: ADMIN },
      ['CREATE UNIQUE INDEX idx_options_name ON options (name)'],
    );

    make(
      'services',
      [
        txt('name', { required: true, min: 2, max: 80 }),
        txt('description', { max: 300 }),
        num('price', { required: true, min: 0, max: 1000000 }),
        dt('deletedAt'),
      ],
      { list: `${AUTH} && ${LIVE}`, create: ADMIN, update: ADMIN, delete: ADMIN },
      ['CREATE UNIQUE INDEX idx_services_name ON services (name)'],
    );

    // ---------- модели и автомобили ----------
    make(
      'car_models',
      [
        rel('brand', 'brands', { required: true }),
        txt('name', { required: true, min: 1, max: 60 }),
        sel('bodyType', ['sedan', 'hatchback', 'wagon', 'suv', 'coupe', 'minivan', 'pickup'], {
          required: true,
        }),
        num('seats', { min: 2, max: 9, onlyInt: true }),
        dt('deletedAt'),
      ],
      {
        list: `${AUTH} && ${LIVE}`,
        create: STAFF,
        update: `${STAFF} && ${SOFT}`,
        delete: ADMIN,
      },
      ['CREATE UNIQUE INDEX idx_models_brand_name ON car_models (brand, name)'],
    );

    make(
      'cars',
      [
        rel('model', 'car_models', { required: true }),
        txt('vin', { required: true, pattern: '^[A-HJ-NPR-Z0-9]{17}$' }),
        num('year', { required: true, min: 1990, max: 2100, onlyInt: true }),
        txt('color', { max: 40 }),
        num('mileage', { min: 0, max: 2000000, onlyInt: true }),
        num('price', { required: true, min: 100000, max: 100000000 }),
        sel('engine', ['petrol', 'diesel', 'hybrid', 'electric'], { required: true }),
        sel('transmission', ['manual', 'automatic', 'robot', 'cvt'], { required: true }),
        num('horsepower', { min: 30, max: 2000, onlyInt: true }),
        sel('status', ['available', 'reserved', 'sold'], { required: true }),
        rel('options', 'options', { maxSelect: 20 }),
        dt('deletedAt'),
      ],
      {
        list:
          `${AUTH} && ((${ROLE} = "client" && deletedAt = "" && status != "sold")` +
          ` || (${ROLE} = "manager" && deletedAt = "") || ${ADMIN})`,
        create: STAFF,
        update: `${STAFF} && ${SOFT}`,
        delete: ADMIN,
      },
      ['CREATE UNIQUE INDEX idx_cars_vin ON cars (vin)'],
    );

    // ---------- клиенты ----------
    make(
      'customers',
      [
        rel('user', 'users'),
        txt('fullName', { required: true, min: 5, max: 120 }),
        txt('phone', { pattern: '^\\+?[0-9\\s\\-()]{10,20}$' }),
        { type: 'email', name: 'email' },
        txt('city', { max: 60 }),
        dt('birthDate'),
        dt('deletedAt'),
      ],
      {
        list:
          `${ADMIN} || (${ROLE} = "manager" && deletedAt = "")` +
          ` || (${ROLE} = "client" && user = @request.auth.id && deletedAt = "")`,
        create: STAFF,
        update:
          `(${STAFF} && ${SOFT}) || (${ROLE} = "client" && user = @request.auth.id` +
          ' && @request.body.user:isset = false && @request.body.deletedAt:isset = false)',
        delete: ADMIN,
      },
      ['CREATE UNIQUE INDEX idx_customers_user ON customers (user) WHERE user != ""'],
    );

    // ---------- тест-драйвы ----------
    const own = (field) => `${ROLE} = "client" && ${field}.user = @request.auth.id`;
    make(
      'test_drives',
      [
        rel('car', 'cars', { required: true }),
        rel('customer', 'customers', { required: true }),
        dt('startsAt', { required: true }),
        dt('endsAt', { required: true }),
        sel('status', ['planned', 'done', 'cancelled'], { required: true }),
        txt('comment', { max: 300 }),
        dt('deletedAt'),
      ],
      {
        list:
          `${ADMIN} || (${ROLE} = "manager" && deletedAt = "")` +
          ` || (${own('customer')} && deletedAt = "")`,
        create: AUTH,
        update: `(${STAFF} && ${SOFT}) || (${own('customer')} && @request.body.status = "cancelled")`,
        delete: ADMIN,
      },
    );

    // ---------- сделки и договоры ----------
    make(
      'deals',
      [
        rel('customer', 'customers', { required: true }),
        rel('car', 'cars', { required: true }),
        rel('manager', 'users'),
        rel('services', 'services', { maxSelect: 20 }),
        sel('status', ['new', 'approved', 'signed', 'cancelled'], { required: true }),
        sel('paymentType', ['cash', 'credit', 'leasing'], { required: true }),
        num('discountPercent', { min: 0, max: 30 }),
        num('tradeInValue', { min: 0, max: 100000000 }),
        num('downPayment', { min: 0, max: 100000000 }),
        num('termMonths', { min: 0, max: 84, onlyInt: true }),
        num('totalPrice', { min: 0 }),
        txt('note', { max: 500 }),
        dt('deletedAt'),
      ],
      {
        list:
          `${ADMIN} || (${ROLE} = "manager" && deletedAt = "")` +
          ` || (${own('customer')} && deletedAt = "")`,
        create: AUTH,
        update: `${STAFF} && ${SOFT}`,
        delete: ADMIN,
      },
    );

    make(
      'contracts',
      [
        rel('deal', 'deals', { required: true }),
        txt('number', { max: 30 }),
        dt('signedAt', { required: true }),
        num('amount', { required: true, min: 1 }),
        num('warrantyMonths', { min: 0, max: 120, onlyInt: true }),
        dt('deletedAt'),
      ],
      {
        list:
          `${ADMIN} || (${ROLE} = "manager" && deletedAt = "")` +
          ` || (${ROLE} = "client" && deal.customer.user = @request.auth.id && deletedAt = "")`,
        create: `${ROLE} = "manager"`,
        update: `${ROLE} = "manager" && ${SOFT}`,
        delete: ADMIN,
      },
      [
        'CREATE UNIQUE INDEX idx_contracts_deal ON contracts (deal)',
        'CREATE UNIQUE INDEX idx_contracts_number ON contracts (number) WHERE number != ""',
      ],
    );
  },
  (app) => {
    for (const name of [
      'contracts',
      'deals',
      'test_drives',
      'customers',
      'cars',
      'car_models',
      'services',
      'options',
      'brands',
    ]) {
      app.delete(app.findCollectionByNameOrId(name));
    }
    const users = app.findCollectionByNameOrId('users');
    users.fields.removeByName('role');
    users.fields.removeByName('phone');
    app.save(users);
  },
);
