(* All the HTTP entry points are listed here as routes.

   Don't put actual logic here to keep it declarative and easy to read.
   The overall scope of the web app should be clear after scanning the routes.
*)

let list_todos = Sihl.Web.Http.get "" Handler.list
let add_todos = Sihl.Web.Http.post "add" Handler.add
let do_todos = Sihl.Web.Http.post "do" Handler.do_

let site_router =
  Sihl.Web.Http.router
    ~middlewares:(Middleware.site ())
    ~scope:"/"
    [ list_todos; add_todos; do_todos ]
;;

let list_todos_json = Sihl.Web.Http.get "" Handler.list_json

let api_router =
  Sihl.Web.Http.router
    ~middlewares:(Middleware.json_api ())
    ~scope:"/api"
    [ list_todos_json ]
;;

(* The list of routers is used by the HTTP service that is configured in run.ml. *)
let all = [ site_router; api_router ]
