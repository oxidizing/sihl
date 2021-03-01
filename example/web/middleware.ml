(* Use these middlewares for your good ole server side rendered forms. *)
let site () =
  [ Sihl.Web.Id.middleware
  ; Sihl.Web.Error.middleware ()
  ; Opium.Middleware.logger
  ; Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Sihl.Web.Static.middleware ()
  ; Sihl.Web.Session.middleware ()
  ; Sihl.Web.Form.middleware
  ; Sihl.Web.Csrf.middleware ()
  ; Sihl.Web.Flash.middleware ()
  ; Sihl.Web.User.session_middleware Service.User.find_opt
  ]
;;

(* Use these middlewares for JSON APIs. *)
let json_api () =
  [ Sihl.Web.Id.middleware
  ; Opium.Middleware.logger
  ; Sihl.Web.Error.middleware ()
  ; Sihl.Web.Json.middleware
  ; Sihl.Web.Bearer_token.middleware
  ; Sihl.Web.User.token_middleware
      (fun token ~k -> Service.Token.read token ~k)
      Service.User.find_opt
      Service.Token.deactivate
  ]
;;
