let config =
  Sihl.Core.Config.Setting.create ~development:[]
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
    Sihl.Middleware.db;
    Sihl.Middleware.cookie;
    Sihl.Middleware.static;
    Sihl_session.middleware;
    Sihl.Middleware.flash;
    Sihl.Middleware.error;
    Sihl_user.Middleware.Authn.token;
    Sihl_user.Middleware.Authn.session;
  ]

(* module MigrationService = Sihl.Migration.PostgreSql
 * module SessionService = Shil.Session.PostgresSql
 *
 * module EmailTransport = Sihl.Email.Transport.Smtp.Make (struct
 *   (\* Configs could be fetched from some external place *\)
 *   let smtp_host = Lwt.return "foo"
 *
 *   let smtp_port = Lwt.return 876
 *
 *   let smtp_secure = Lwt.return false
 * end)
 *
 * module EmailService =
 *   Shil.Email.Make (EmailTransport) (Sihl.Email.Repo.Postgresql)
 * module UserService =
 *   Sihl.User.Make (Sihl.Authn.Default) (Sihl.User.Repo.Postgresql)
 *
 * let register_services =
 *   [ MigrationService; SessionService; EmailService; UserService ] *)

let bindings =
  [
    Sihl_session_postgresql.bind;
    Sihl_email_postgresql.bind;
    Sihl_user_postgresql.bind;
  ]

let project =
  Sihl.Run.Project.Project.create ~config ~bindings middlewares
    [
      (module Sihl_session.App); (module Sihl_email.App); (module Sihl_user.App);
    ]

let () = Sihl.Run.Project.Project.run_command project
