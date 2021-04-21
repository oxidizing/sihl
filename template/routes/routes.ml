let global_middlewares =
  [ Sihl.Web.Middleware.id ()
  ; Sihl.Web.Middleware.error ()
  ; Sihl.Web.Middleware.static_file ()
  ]
;;

module Site = struct
  let hello = Sihl.Web.get "/" Handler.Page.hello

  let middlewares =
    [ Opium.Middleware.content_length
    ; Opium.Middleware.etag
    ; Sihl.Web.Middleware.migration Service.Migration.pending_migrations
    ; Sihl.Web.Middleware.csrf ()
    ; Sihl.Web.Middleware.flash ()
    ]
  ;;
end

module Api = struct
  let hello = Sihl.Web.get "/" Handler.Api.hello
  let middlewares = []
end

let router =
  Sihl.Web.(
    choose
      ~scope:"/"
      [ choose ~middlewares:Site.middlewares [ Site.hello ]
      ; choose ~scope:"/api" ~middlewares:Api.middlewares [ Api.hello ]
      ])
;;
