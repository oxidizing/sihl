(* All the HTML HTTP entry points are listed here.

   Don't put actual logic here to keep it declarative and easy to read. The
   overall scope of the web app should be clear after scanning the routes. *)

let hello = Sihl.Web.Http.get "/" Handler.Page.hello

let middlewares =
  [ Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Sihl.Web.Middleware.session ()
  ; Sihl.Web.Middleware.form
  ; Sihl.Web.Middleware.csrf ()
  ; Sihl.Web.Middleware.flash ()
  ]
;;

let router = Sihl.Web.Http.router ~middlewares ~scope:"/" [ hello ]
