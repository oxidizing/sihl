let config =
  Sihl_core.Config.Setting.create ~development:[]
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
    Sihl_core.Middleware.cookie;
    Sihl_core.Middleware.static;
    Sihl_core.Middleware.flash;
    Sihl_core.Middleware.error;
    Sihl_core.Middleware.db;
    Sihl_user.Middleware.Authn.token;
    Sihl_user.Middleware.Authn.session;
  ]

let project =
  Sihl_core.Run.Project.create ~config middlewares
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl_core.Run.Project.run_command project
