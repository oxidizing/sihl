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

let apps = [Sihl.Users.App.app(adminUiPages), App.app()];

Sihl.Core.Main.Cli.execute(apps, Node.Process.argv);
