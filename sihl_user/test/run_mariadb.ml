let config =
  Sihl_core.Config.Setting.create ~development:[]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "hello@oxidizing.io");
        ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev");
        ("EMAIL_BACKEND", "memory");
      ]
    ~production:[]

let bindings =
  [
    Sihl_core.Registry.bind Sihl_email.Contract.repository
      (module Sihl_email.Repository_mariadb);
    Sihl_core.Registry.bind Sihl_email.Contract.migration
      (module Sihl_email.Migration_mariadb);
    Sihl_core.Registry.bind Sihl_user.Contract.repository
      (module Sihl_user.Database.MariaDb.Repository);
    Sihl_core.Registry.bind Sihl_user.Contract.migration
      (module Sihl_user.Database.MariaDb.Migration);
    Sihl_core.Registry.bind Sihl_core.Contract.Migration.repository
      (module Sihl_core.Db.Migrate.MariaDbRepository);
  ]

let project =
  Sihl_core.Run.Project.create ~bindings ~config
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl_core.Run.Project.run_command project
