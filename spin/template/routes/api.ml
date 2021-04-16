(* All the JSON HTTP entry points are listed here.

   Don't put actual logic here to keep it declarative and easy to read. The
   overall scope of the web app should be clear after scanning the routes. *)

let middlewares = [ Sihl.Web.Middleware.json; Sihl.Web.Middleware.bearer_token ]
let router = Sihl.Web.Http.router ~middlewares ~scope:"/api" []
