let site () =
  [ Sihl.Web.Id.middleware
  ; Sihl.Web.Error.site_middleware
  ; Opium.Middleware.logger
  ; Opium.Middleware.content_length
  ; Opium.Middleware.head
  ; Opium.Middleware.etag
  ; Sihl.Web.Static.middleware ()
  ; Sihl.Web.Session.middleware ()
  ; Sihl.Web.Form.middleware
  ; Sihl.Web.Csrf.middleware ()
  ; Sihl.Web.User.session_middleware ()
  ]
;;

let json_api () =
  [ Sihl.Web.Id.middleware
  ; Opium.Middleware.logger
  ; Sihl.Web.Error.json_middleware
  ; Sihl.Web.Json.middleware
  ; Sihl.Web.Bearer_token.middleware
  ; Sihl.Web.User.token_middleware ()
  ]
;;
