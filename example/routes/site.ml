let list_todos = Sihl.Web.Http.get "" Handler.Todos.list
let add_todos = Sihl.Web.Http.post "add" Handler.Todos.add
let do_todos = Sihl.Web.Http.post "do" Handler.Todos.do_

let middlewares =
  [ Sihl.Web.Middleware.id
  ; Sihl.Web.Middleware.error ()
  ; Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Sihl.Web.Middleware.static_file ()
  ; Sihl.Web.Middleware.session ()
  ; Sihl.Web.Middleware.form
  ; Sihl.Web.Middleware.csrf ()
  ; Sihl.Web.Middleware.flash ()
  ; Sihl.Web.Middleware.user (fun user_id -> Service.User.find_opt ~user_id)
  ]
;;

let router =
  Sihl.Web.Http.router
    ~middlewares
    ~scope:"/"
    [ list_todos; add_todos; do_todos ]
;;
