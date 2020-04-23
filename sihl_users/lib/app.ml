let name = "User Management App"

let namespace = "users"

let config =
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

let middlewares =
  Handler.
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

let migrations = Migration.migrations

let cleaners = [ Repository.Token.clean; Repository.User.clean ]

let commands = [ Command.create_admin ]
