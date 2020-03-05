let adminUiPages = [
  Sihl.Users.AdminUi.Page.make(
    ~path="/admin/issues/issues/",
    ~label="Issues",
  ),
  Sihl.Users.AdminUi.Page.make(
    ~path="/admin/issues/boards/",
    ~label="Boards",
  ),
];

Sihl.Core.Main.Manager.startApps([
  Sihl.Users.App.app(adminUiPages),
  App.app(),
]);
