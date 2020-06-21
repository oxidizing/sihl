let config =
  Sihl.Core.Config.Setting.create ~development:[]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "hello@oxidizing.io");
        ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev");
        ("EMAIL_BACKEND", "memory");
      ]
    ~production:[]

let middlewares =
  [
    Sihl.Middleware.db;
    Sihl.Middleware.cookie;
    Sihl.Middleware.static;
    Sihl.Middleware.session;
    Sihl.Middleware.flash;
    Sihl.Middleware.error;
    Sihl_user.Middleware.Authn.token;
    Sihl_user.Middleware.Authn.session;
  ]

module EmailService =
  Sihl.Email.Service.Make.Memory (Sihl.Email.Service.Template.PostgreSql)

let email_service =
  Sihl.Container.create_binding Sihl.Email.Sig.key
    (module EmailService)
    (module EmailService)

let services =
  [
    Sihl.Migration.Service.postgresql;
    email_service;
    Sihl_user.Service.postgresql;
    Sihl.Session.Service.postgresql;
  ]

let project =
  Sihl.Run.Project.Project.create ~config ~services middlewares
    [ (module Sihl_user.App) ]

let () = Sihl.Run.Project.Project.run_command project
