let name = "User Management App"

let namespace = "users"

let config () =
  Sihl_core.Config.Schema.
    [
      string_ ~default:"console"
        ~choices:[ "smtp"; "console"; "memory" ]
        "EMAIL_BACKEND";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_HOST";
      int_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_PORT";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_AUTH_USERNAME";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_AUTH_PASSWORD";
      bool_ ~default:false "SMTP_SECURE";
      bool_ ~default:false "SMTP_POOL";
    ]

let middlewares () =
  let open Handler in
  [
    Middleware.Authentication.middleware;
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

let bind () =
  [
    Sihl_core.Registry.bind Contract.repository
      (module Database.Postgres.Repository);
    Sihl_core.Registry.bind Contract.migration
      (module Database.Postgres.Migration);
  ]

let commands () = [ Command.create_admin ]
