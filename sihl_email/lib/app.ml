let name = "Email Management App"

let namespace = "emails"

let config () =
  Sihl_core.Config.Schema.
    [
      string_ ~default:"console"
        ~choices:[ "smtp"; "console"; "memory"; "sendgrid" ]
        "EMAIL_BACKEND";
      string_ ~required_if:("EMAIL_BACKEND", "sendgrid") "SENDGRID_API_KEY";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_HOST";
      int_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_PORT";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_AUTH_USERNAME";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_AUTH_PASSWORD";
      bool_ ~default:false "SMTP_SECURE";
      bool_ ~default:false "SMTP_POOL";
    ]

let middlewares () = []

let migrations () =
  let (module Migration : Sihl_core.Contract.Migration.MIGRATION) =
    Sihl_core.Registry.get Contract.migration
  in
  Migration.migration ()

let repositories () = []

let bindings () =
  [
    Sihl_core.Registry.Binding.create Contract.repository
      (module Repository_postgres);
    Sihl_core.Registry.Binding.create Contract.migration
      (module Migration_postgres);
    Service.bind ();
  ]

let commands () = []

let start () = Ok ()

let stop () = Ok ()
