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
    Sihl.Middleware.db;
    Sihl.Middleware.cookie;
    Sihl.Middleware.static;
    Sihl_session.middleware;
    Sihl.Middleware.flash;
    Sihl.Middleware.error;
    Sihl_user.Middleware.Authn.token;
    Sihl_user.Middleware.Authn.session;
  ]

let services =
  [
    Sihl_session_mariadb.bind;
    Sihl_email_mariadb.bind;
    Sihl_user_mariadb.bind;
    Sihl.Migration.mariadb;
  ]

let project =
  Sihl.Run.Project.Project.create ~services ~config middlewares
    [
      (module Sihl_session.App); (module Sihl_email.App); (module Sihl_user.App);
    ]

let () = Sihl.Run.Project.Project.run_command project
