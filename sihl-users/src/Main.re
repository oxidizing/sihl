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
  };
};

App.start();
