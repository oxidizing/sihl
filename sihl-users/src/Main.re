module Settings = {
  let name = "User Management App";
  let root = "users";
  let routes = [
    Http.Http.Route.post("/register", Routes.register),
    Http.Http.Route.get("/login", Routes.login),
  ];
};

module App = {
  let start = () => {
    Sihl.Core.Log.info("Starting app " ++ Settings.name, ());
    let _ = Http.Adapter.startServer(~port=3000, Settings.routes);
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};

App.start();
