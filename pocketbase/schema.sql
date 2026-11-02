CREATE TABLE `users` (`avatar` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL, `emailVisibility` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `password` TEXT DEFAULT '' NOT NULL, `tokenKey` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `verified` BOOLEAN DEFAULT FALSE NOT NULL, "role" TEXT DEFAULT '' NOT NULL, "phone" TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_tokenKey__pb_users_auth_` ON `users` (`tokenKey`);
CREATE UNIQUE INDEX `idx_email__pb_users_auth_` ON `users` (`email`) WHERE `email` != '';

CREATE TABLE `brands` (`country` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `foundedYear` NUMERIC DEFAULT 0 NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_brands_name` ON `brands` (`name`);

CREATE TABLE `options` (`category` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_options_name` ON `options` (`name`);

CREATE TABLE `services` (`created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_services_name` ON `services` (`name`);

CREATE TABLE `car_models` (`bodyType` TEXT DEFAULT '' NOT NULL, `brand` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `seats` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_models_brand_name` ON `car_models` (
  `brand`,
  `name`
);

CREATE TABLE `cars` (`color` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `engine` TEXT DEFAULT '' NOT NULL, `horsepower` NUMERIC DEFAULT 0 NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `mileage` NUMERIC DEFAULT 0 NOT NULL, `model` TEXT DEFAULT '' NOT NULL, `options` JSON DEFAULT '[]' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `transmission` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `vin` TEXT DEFAULT '' NOT NULL, `year` NUMERIC DEFAULT 0 NOT NULL);

CREATE UNIQUE INDEX `idx_cars_vin` ON `cars` (`vin`);

CREATE TABLE `customers` (`birthDate` TEXT DEFAULT '' NOT NULL, `city` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL, `fullName` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `phone` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_customers_user` ON `customers` (`user`) WHERE user != "";

CREATE TABLE `test_drives` (`car` TEXT DEFAULT '' NOT NULL, `comment` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `customer` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `endsAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `startsAt` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);


CREATE TABLE `deals` (`car` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `customer` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `discountPercent` NUMERIC DEFAULT 0 NOT NULL, `downPayment` NUMERIC DEFAULT 0 NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `manager` TEXT DEFAULT '' NOT NULL, `note` TEXT DEFAULT '' NOT NULL, `paymentType` TEXT DEFAULT '' NOT NULL, `services` JSON DEFAULT '[]' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `termMonths` NUMERIC DEFAULT 0 NOT NULL, `totalPrice` NUMERIC DEFAULT 0 NOT NULL, `tradeInValue` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);


CREATE TABLE `contracts` (`amount` NUMERIC DEFAULT 0 NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deal` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `number` TEXT DEFAULT '' NOT NULL, `signedAt` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `warrantyMonths` NUMERIC DEFAULT 0 NOT NULL);

CREATE UNIQUE INDEX `idx_contracts_deal` ON `contracts` (`deal`);
CREATE UNIQUE INDEX `idx_contracts_number` ON `contracts` (`number`) WHERE number != "";
