let config =
  Sihl_core.Config.Setting.create
    ~development:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "josef@oxidizing.io");
        ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev");
        ("EMAIL_BACKEND", "console");
      ]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "josef@oxidizing.io");
        ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev");
        ("EMAIL_BACKEND", "memory");
      ]
    ~production:
      [
        ("EMAIL_BACKEND", "smtp");
        ("BASE_URL", "https://sihl-example-issues.oxidizing.io");
        ("SMTP_SECURE", "false");
        ("SMTP_HOST", "smtp.sendgrid.net");
        ("SMTP_PORT", "587");
        ("SMTP_AUTH_USERNAME", "apikey");
      ]

let bind () =
  [
    Sihl_core.Registry.bind Sihl_users.Contract.repository
      (module Sihl_users.Database.MariaDb.Repository);
    Sihl_core.Registry.bind Sihl_users.Contract.migration
      (module Sihl_users.Database.MariaDb.Migration);
    Sihl_core.Registry.bind Sihl_core.Contract.Migration.repository
      (module Sihl_core.Db.Migrate.MariaDbRepository);
  ]

let project =
  Sihl_core.Run.Project.create ~bind ~config [ (module Sihl_users.App) ]

let () = Sihl_core.Run.Project.run_command project
