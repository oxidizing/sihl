let config =
  Sihl.Core.Config.Setting.create
    ~development:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "hello@oxidizing.io");
        ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev");
        ("EMAIL_BACKEND", "console");
      ]
    ~test:
      [
        ("BASE_URL", "http://localhost:3000");
        ("EMAIL_SENDER", "hello@oxidizing.io");
        ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev");
        ("EMAIL_BACKEND", "memory");
      ]
    ~production:
      [
        ("EMAIL_BACKEND", "sendgrid");
        ("BASE_URL", "https://sihl-example-issues.oxidizing.io");
        ("EMAIL_SENDER", "hello@oxidizing.io");
      ]

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

let bindings =
  [
    Sihl_session_postgresql.bind;
    Sihl_email_postgresql.bind;
    Sihl_user_postgresql.bind;
  ]

let project =
  Sihl.Run.Project.Project.create ~config ~bindings middlewares
    [
      (module Sihl_session.App);
      (module Sihl_admin.App);
      (module Sihl_email.App);
      (module Sihl_user.App);
    ]

let () = Sihl.Run.Project.Project.run_command project
