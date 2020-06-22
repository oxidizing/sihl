let name = "User Management App"

let namespace = "user"

let config () =
  Sihl.Core.Config.Schema.
    [
      string_ ~default:"http://localhost:3000" "BASE_URL";
      string_ ~default:"hello@oxidizing.io" "EMAIL_SENDER";
    ]

let endpoints () =
  [ (* TODO fix once we have defined user service, token service and use case layer *)
    (* Login.handler;
     * Register.handler;
     * Logout.handler;
     * GetUser.handler;
     * GetUsers.handler;
     * GetMe.handler;
     * UpdatePassword.handler;
     * UpdateDetails.handler;
     * SetPassword.handler;
     * ConfirmEmail.handler;
     * RequestPasswordReset.handler;
     * ResetPassword.handler;
     * AdminUi.Login.get;
     * AdminUi.Login.post;
     * AdminUi.Logout.handler;
     * AdminUi.User.handler;
     * AdminUi.Users.handler;
     * AdminUi.UserSetPassword.handler; *) ]

let repos () = []

module AuthenticationService = struct
  let on_bind _ = Lwt.return @@ Ok ()

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let authenticate = Middleware.Authn.authenticate
end

let bindings () =
  [
    Sihl.Core.Container.create_binding Sihl.Authn.Service.key
      (module AuthenticationService)
      (module AuthenticationService);
  ]

let commands () = [ Command.create_admin ]

let start () =
  Ok
    (Sihl.Admin.register_page
       (Sihl.Admin.Page.create ~label:"Users" ~path:"/admin/users/users/"))

let stop () = Ok ()
