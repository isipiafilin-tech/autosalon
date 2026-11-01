import 'enums.dart';

/// Права, от которых зависит видимость разделов и действий.
/// Сервер проверяет те же правила самостоятельно (правила доступа PocketBase).
enum Permission {
  viewCatalog,
  manageCars,
  manageDictionaries,
  manageCustomers,
  manageDeals,
  manageTestDrives,
  clientCabinet,
  manageContracts,
  manageUsers,
  viewTrash,
}

const _byRole = <Role, Set<Permission>>{
  Role.client: {Permission.viewCatalog, Permission.clientCabinet},
  Role.manager: {
    Permission.viewCatalog,
    Permission.manageCars,
    Permission.manageCustomers,
    Permission.manageDeals,
    Permission.manageTestDrives,
    Permission.manageContracts,
  },
  Role.admin: {
    Permission.viewCatalog,
    Permission.manageCars,
    Permission.manageDictionaries,
    Permission.manageCustomers,
    Permission.manageDeals,
    Permission.manageTestDrives,
    Permission.manageUsers,
    Permission.viewTrash,
  },
};

bool roleCan(Role role, Permission permission) =>
    _byRole[role]?.contains(permission) ?? false;
