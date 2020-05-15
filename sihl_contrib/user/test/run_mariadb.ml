let config =
  Sihl.Core.Config.Setting.create ~development:[]
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
    Sihl.Core.Registry.bind Sihl_email.Bind.Repository.key
      (module Sihl_email.Repo_mariadb);
    Sihl.Core.Registry.bind Sihl_user.Binding.Repository.key
      (module Sihl_user.Repository_mariadb);
    Sihl.Core.Registry.bind Sihl.Core.Contract.Migration.repository
      (module Sihl.Repo.Migration.MariaDbRepository);
  ]

let project =
  Sihl.Run.Project.Project.create ~bindings ~config middlewares
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl.Run.Project.Project.run_command project
