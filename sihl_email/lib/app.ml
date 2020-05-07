let name = "Email Management App"

let namespace = "emails"

let config () =
  Sihl_core.Config.Schema.
    [
      string_ ~default:"console"
        ~choices:[ "smtp"; "console"; "memory" ]
        "EMAIL_BACKEND";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_HOST";
      int_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_PORT";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_AUTH_USERNAME";
      string_ ~required_if:("EMAIL_BACKEND", "smtp") "SMTP_AUTH_PASSWORD";
      bool_ ~default:false "SMTP_SECURE";
      bool_ ~default:false "SMTP_POOL";
    ]

let middlewares () = []

let migrations () = Migration_postgres.migration ()

let repositories () = []

let bind () =
  [ Sihl_core.Registry.bind Contract.repository (module Repository_postgres) ]

let commands () = []
