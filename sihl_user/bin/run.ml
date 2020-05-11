let config =
  Sihl_core.Config.Setting.create
    ~development:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "josef@oxidizing.io");
        ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev");
        ("EMAIL_BACKEND", "console");
      ]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "josef@oxidizing.io");
        ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev");
        ("EMAIL_BACKEND", "memory");
      ]
    ~production:
      [
        ("EMAIL_BACKEND", "sendgrid");
        ("BASE_URL", "https://sihl-example-issues.oxidizing.io");
        ("EMAIL_SENDER", "josef@oxidizing.io");
        ("DATABASE_URL", "");
        ("SENDGRID_API_KEY", "");
      ]

let project =
  Sihl_core.Run.Project.create ~config
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl_core.Run.Project.run_command project
