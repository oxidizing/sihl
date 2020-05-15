let name = "User Management App"

let namespace = "users"

let config () =
  Sihl.Core.Config.Schema.
    [
      string_ ~default:"http://localhost:3000" "BASE_URL";
      string_ ~default:"hello@oxidizing.io" "EMAIL_SENDER";
    ]

let endpoints () =
  let open Handler in
  [
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

let repos () = Binding.Repository.default ()

let bindings () = Binding.default

let commands () = [ Command.create_admin ]

let start () =
  Ok
    (Admin_ui.register_page
       (Admin_ui.Page.create ~label:"Users" ~path:"/admin/users/users/"))

let stop () = Ok ()
