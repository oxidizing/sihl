let hello_page = Sihl.Web.Http.get "/hello/" Handler.hello_page
let site_router = Sihl.Web.Http.router ~scope:"/page" [ hello_page ]
let api_router = Sihl.Web.Http.router ~scope:"/api" [ hello_page ]
let all = [ site_router; api_router ]
