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
    Sihl.Middleware.cookie;
    Sihl.Middleware.static;
    Sihl.Middleware.flash;
    Sihl.Middleware.error;
    Sihl.Middleware.db;
    Sihl_user.Middleware.Authn.token;
    Sihl_user.Middleware.Authn.session;
  ]

let bindings =
  [
    Sihl_postgresql.bind; Sihl_email_postgresql.bind; Sihl_user_postgresql.bind;
  ]

let project =
  Sihl.Run.Project.Project.create ~config ~bindings middlewares
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl.Run.Project.Project.run_command project
