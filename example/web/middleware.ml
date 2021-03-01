(* Use these middlewares for your good ole server side rendered forms. *)
let site () =
  [ Sihl.Web.Middleware.id
  ; Sihl.Web.Middleware.error ()
  ; Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Sihl.Web.Middleware.static_file ()
  ; Sihl.Web.Middleware.session ()
  ; Sihl.Web.Middleware.form
  ; Sihl.Web.Middleware.csrf ()
  ; Sihl.Web.Middleware.flash ()
  ; Sihl.Web.Middleware.user_session Service.User.find_opt
  ]
;;

(* Use these middlewares for JSON APIs. *)
let json_api () =
  [ Sihl.Web.Middleware.id
  ; Sihl.Web.Middleware.error ()
  ; Sihl.Web.Middleware.json
  ; Sihl.Web.Middleware.bearer_token
  ; Sihl.Web.Middleware.user_token
      (fun token ~k -> Service.Token.read token ~k)
      Service.User.find_opt
      Service.Token.deactivate
  ]
;;
