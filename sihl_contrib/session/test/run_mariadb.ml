let config =
  Sihl.Core.Config.Setting.create ~development:[]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev");
      ]
    ~production:[]

let middlewares =
  [ Sihl.Middleware.db; Sihl.Middleware.cookie; Sihl_session.middleware ]

let services = [ Sihl_session_mariadb.bind; Sihl.Migration.Service.mariadb ]

let project =
  Sihl.Run.Project.Project.create ~config ~services middlewares
    [ (module Sihl_session.App) ]

let () = Sihl.Run.Project.Project.run_command project
