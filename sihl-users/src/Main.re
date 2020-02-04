module Settings = {
  open Sihl.Core.Http;
  let name = "User Management App";
  let root = "users";
  let routes = [
    Route.post("/register/", Routes.register),
    Route.get("/login/", Routes.login),
    Route.get("/", Routes.users |> Routes.auth),
    Route.get("/:id/", Routes.user |> Routes.auth),
    Route.get("/me/", Routes.myUser |> Routes.auth),
    Route.post(
      "/request-password-reset/",
      Routes.requestPasswordReset |> Routes.auth,
    ),
    Route.post("/reset-password/", Routes.resetPassword |> Routes.auth),
    Route.post("/update-password/", Routes.updatePassword |> Routes.auth),
    Route.post("/set-password/", Routes.setPassword |> Routes.auth),
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
