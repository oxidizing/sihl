let name = "User Management App";
let namespace = "users";

let routes = database => [
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
  Routes.AdminUi.GetMe.endpoint(namespace, database),
];

let app =
  Sihl.Core.Main.App.make(
    ~name,
    ~namespace,
    ~routes,
    ~clean=[Repository.Token.Clean.run, Repository.User.Clean.run],
    ~migration=Migrations.MariaDb.make(~namespace),
  );
