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
    Sihl.Middleware.session;
    Sihl.Middleware.flash;
    Sihl.Middleware.error;
    Sihl_user.Middleware.Authn.token;
    Sihl_user.Middleware.Authn.session;
  ]

module EmailConfigProvider = struct
  let api_key _ = Lwt.return @@ Ok "TODO"
end

module EmailService =
  Sihl.Email.Service.Make.SendGrid
    (Sihl.Email.Service.Template.PostgreSql)
    (EmailConfigProvider)

let email_service =
  Sihl.Container.create_binding Sihl.Email.Sig.key
    (module EmailService)
    (module EmailService)

let services = [ email_service; Sihl_user.Service.postgresql ]

let project =
  Sihl.Run.Project.Project.create ~config ~services middlewares
    [ (module Sihl_admin.App); (module Sihl_user.App) ]

let () = Sihl.Run.Project.Project.run_command project
