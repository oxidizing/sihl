(* All the HTTP entry points are listed here as routes.

   Don't put actual logic here to keep it declarative and easy to read. The
   overall scope of the web app should be clear after scanning the routes. *)

let list_todos_json = Sihl.Web.Http.get "" Handler.Todos.list_json

let middlewares =
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

let router = Sihl.Web.Http.router ~middlewares ~scope:"/api" [ list_todos_json ]
