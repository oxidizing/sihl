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

let project =
  Sihl_core.Run.Project.create ~config
    [ (module Sihl_email.App); (module Sihl_user.App) ]

let () = Sihl_core.Run.Project.run_command project
