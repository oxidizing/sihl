let middlewares =
  [ Sihl.Web.Middleware.id
  ; Sihl.Web.Middleware.error ()
  ; Sihl.Web.Middleware.static_file ()
  ]
;;
