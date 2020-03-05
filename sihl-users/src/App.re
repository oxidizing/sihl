let name = "User Management App";
let namespace = "users";

let adminUiPages = [
  AdminUi.Navigation.Item.make(~path="/admin/", ~label="Dashboard"),
  AdminUi.Navigation.Item.make(~path="/admin/users/users/", ~label="Users"),
];

let routes = (externalAdminUiPages, database) => {
  let adminUiPages = Belt.List.concat(adminUiPages, externalAdminUiPages);
  [
    Routes.Login.endpoint(namespace, database),
    Routes.Register.endpoint(namespace, database),
    Routes.ConfirmEmail.endpoint(namespace, database),
    Routes.RequestPasswordReset.endpoint(namespace, database),
    Routes.ResetPassword.endpoint(namespace, database),
    Routes.UpdatePassword.endpoint(namespace, database),
    Routes.SetPassword.endpoint(namespace, database),
    Routes.UpdateUserDetails.endpoint(namespace, database),
    Routes.GetMe.endpoint(namespace, database),
    Routes.GetUser.endpoint(namespace, database),
    Routes.GetUsers.endpoint(namespace, database),
    Routes.AdminUi.Dashboard.endpoint(namespace, database, adminUiPages),
    Routes.AdminUi.Login.endpoint(namespace, database),
    Routes.AdminUi.Users.endpoint(namespace, database, adminUiPages),
    Routes.AdminUi.User.endpoint(namespace, database, adminUiPages),
  ];
};

let app = adminUiPages =>
  Sihl.Core.Main.App.make(
    ~name,
    ~namespace,
    ~routes=routes(adminUiPages),
    ~clean=[Repository.Token.Clean.run, Repository.User.Clean.run],
    ~migration=Migrations.MariaDb.make(~namespace),
  );
