module Sihl = SihlUsers_Sihl;

let environment =
  Sihl.Core.Config.Environment.make(
    ~development=[
      ("BASE_URL", "http://localhost:3000"),
      ("EMAIL_SENDER", "josef@oxidizing.io"),
      ("DATABASE_URL", "mysql://root:password@localhost:3306/dev"),
      ("EMAIL_BACKEND", "console"),
    ],
    ~test=[
      ("BASE_URL", "http://localhost:3000"),
      ("EMAIL_SENDER", "josef@oxidizing.io"),
      ("DATABASE_URL", "mysql://root:password@localhost:3306/dev"),
      ("EMAIL_BACKEND", "memory"),
    ],
    ~production=[
      ("EMAIL_BACKEND", "smtp"),
      ("BASE_URL", "https://sihl-example-issues.oxidizing.io"),
      ("SMTP_SECURE", "false"),
      ("SMTP_HOST", "smtp.sendgrid.net"),
      ("SMTP_PORT", "587"),
      ("SMTP_AUTH_USERNAME", "apikey"),
    ],
  );

let project =
  Sihl.Core.Main.Project.make(~environment, [SihlUsers_App.app([])]);
