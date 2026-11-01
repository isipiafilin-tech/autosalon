/// <reference path="../pb_data/types.d.ts" />
// Серверные проверки, которые нельзя выразить правилами доступа:
// конфликты (409), ошибки полей (422) и согласованность статусов.
// Логика вынесена в lib.js: обработчики PocketBase выполняются изолированно.

// Регистрация клиента создаёт его карточку (связь один к одному).
onRecordAfterCreateSuccess((e) => {
  require(`${__hooks}/lib.js`).createCustomerProfile(e.app, e.record);
  e.next();
}, 'users');

// Новая сделка: стоимость считает сервер, автомобиль резервируется.
onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  lib.beforeDealCreate(e);
  e.next();
  const car = e.app.findRecordById('cars', e.record.getString('car'));
  car.set('status', 'reserved');
  e.app.save(car);
}, 'deals');

// Изменение сделки: допустимые переходы статусов; отмена освобождает автомобиль.
onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  const { from, to } = lib.beforeDealUpdate(e);
  e.next();
  if (to === 'cancelled' && from !== 'cancelled') lib.releaseCar(e.app, e.record.getString('car'));
}, 'deals');

// Договор: только по одобренной сделке, сумма совпадает; после подписания автомобиль продан.
onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  const deal = lib.beforeContractCreate(e);
  e.next();
  lib.afterContractCreate(e.app, deal);
}, 'contracts');

// Тест-драйв: корректный интервал и отсутствие пересечений по автомобилю.
onRecordCreateRequest((e) => {
  require(`${__hooks}/lib.js`).checkTestDrive(e, true);
  e.next();
}, 'test_drives');

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib.js`).checkTestDrive(e, false);
  e.next();
}, 'test_drives');
