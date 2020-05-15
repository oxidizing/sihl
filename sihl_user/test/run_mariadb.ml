let config =
  Sihl.Config.Setting.create ~development:[]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "hello@oxidizing.io");
        ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev");
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
    Sihl.Registry.bind Sihl_email.Binding.Repository.key
      (module Sihl_email.Repository_mariadb);
    Sihl.Registry.bind Sihl_user.Binding.Repository.key
      (module Sihl_user.Repository_mariadb);
    Sihl.Registry.bind Sihl.Contract.Migration.repository
      (module Sihl.Migration.MariaDbRepository);
  ]

let project =
  Sihl.Run.Project.create ~bindings ~config middlewares
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl.Run.Project.run_command project
