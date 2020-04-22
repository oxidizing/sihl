let name = "User Management App"

let namespace = "users"

let config = Sihl_core.Config.Schema.create ()

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
