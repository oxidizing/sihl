module Settings = {
  let name = "User Management App";
  let root = "users";
  let routes = [
    ExpressHttp.Http.Route.post("/register", Routes.register),
    ExpressHttp.Http.Route.get("/login", Routes.login),
  ];
};

module App = {
  let start = () => {
    Sihl.Core.Log.info("Starting app " ++ Settings.name, ());
    let _ =
      ExpressHttp.Adapter.appConfig(
        ~limitMb=10.0,
        ~compression=true,
        ~hidePoweredBy=true,
        ~urlEncoded=true,
        (),
      )
      |> ExpressHttp.Adapter.makeApp
      |> ExpressHttp.Adapter.mountRoutes(Settings.routes)
      |> ExpressHttp.Adapter.startApp(~port=3000);
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};

App.start();
