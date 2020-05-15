let name = "Email Management App"

let namespace = "emails"

let config () =
  Sihl.Core.Config.Schema.
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

let endpoints () = []

let repos () = Binding.Repository.default ()

let bindings () =
  let backend =
    Sihl.Core.Config.read_string ~default:"memory" "EMAIL_BACKEND"
  in
  [
    Sihl.Core.Registry.Binding.create Binding.Repository.key
      (module Repository_postgres);
    ( match backend with
    | "smtp" ->
        Sihl.Core.Registry.Binding.create Binding.Transport.key
          (module Service.Smtp)
    | "sendgrid" ->
        Sihl.Core.Registry.Binding.create Binding.Transport.key
          (module Service.SendGrid)
    | "console" ->
        Sihl.Core.Registry.Binding.create Binding.Transport.key
          (module Service.Console)
    | _ ->
        Sihl.Core.Registry.Binding.create Binding.Transport.key
          (module Service.Memory) );
  ]

let commands () = []

let start () = Ok ()

let stop () = Ok ()
