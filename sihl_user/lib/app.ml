let name = "User Management App"

let namespace = "users"

let config () = []

let middlewares () =
  let open Handler in
  [
    Middleware.Authn.token_m;
    Middleware.Authn.session_m;
    AdminUi.Catch.handler;
    Login.handler;
    Register.handler;
    Logout.handler;
    GetUser.handler;
    GetUsers.handler;
    GetMe.handler;
    UpdatePassword.handler;
    UpdateDetails.handler;
    SetPassword.handler;
    ConfirmEmail.handler;
    RequestPasswordReset.handler;
    ResetPassword.handler;
    AdminUi.Dashboard.handler;
    AdminUi.Login.get;
    AdminUi.Login.post;
    AdminUi.Logout.handler;
    AdminUi.User.handler;
    AdminUi.Users.handler;
    AdminUi.UserSetPassword.handler;
  ]

let migrations () =
  let (module Migration : Sihl_core.Contract.Migration.MIGRATION) =
    Sihl_core.Registry.get Contract.migration
  in
  Migration.migration ()

(* TODO make this obsolete by:
   1. fetching all repositories from Registry.Repository
   2. calling the clean function *)
let repositories () =
  let (module Repository : Contract.REPOSITORY) =
    Sihl_core.Registry.get Contract.repository
  in
  [ Repository.clean ]

let bindings () =
  [
    Sihl_core.Registry.Binding.create Contract.repository
      (module Database.Postgres.Repository);
    Sihl_core.Registry.Binding.create Contract.migration
      (module Database.Postgres.Migration);
  ]

let commands () = [ Command.create_admin ]

let start () =
  Ok
    (Admin_ui.register_page
       (Admin_ui.Page.create ~label:"Users" ~path:"/admin/users/users/"))

let stop () = Ok ()
