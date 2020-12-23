let hello_page = Sihl.Web.Route.get "/hello/" Handler.hello_page
let site_router = Sihl.Web.Route.router ~scope:"/page" [ hello_page ]
let api_router = Sihl.Web.Route.router ~scope:"/api" [ hello_page ]
let all = [ site_router; api_router ]
