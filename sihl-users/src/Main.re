module Settings = {
  let name = "User Management App";
  let root = "users";
  let routes = [
    Sihl.Core.Http.Route.get("/", Routes.users |> Routes.auth),
    Sihl.Core.Http.Route.get("/:id", Routes.user |> Routes.auth),
    Sihl.Core.Http.Route.get("/me", Routes.myUser |> Routes.auth),
    Sihl.Core.Http.Route.post("/register", Routes.register),
    Sihl.Core.Http.Route.get("/login", Routes.login),
    // Route.post("/request-password-reset", Routes.requestPasswordReset),
    // Route.post("/reset-password", Routes.resetPassword),
    // Route.post("/update-password", Routes.updatePassword),
    // Route.post("/set-password", Routes.setPassword),
  ];
};

module App = {
  let start = () => {
    Sihl.Core.Log.info("Starting app " ++ Settings.name, ());
    let _ = Sihl.Core.Http.Adapter.startServer(~port=3000, Settings.routes);
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};

App.start();
