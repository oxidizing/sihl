module Async = Sihl.Core.Async;

// TODO inject db connection elsewhere
module Database = {
  let pool = (config: Sihl.Core.Config.Db.t) =>
    Sihl.Core.Db.Mysql.pool({
      "user": config.dbUser,
      "host": config.dbHost,
      "database": config.dbName,
      "password": config.dbPassword,
      "port": config.dbPort,
      "waitForConnections": true,
      "connectionLimit": config.connectionLimit,
      "queueLimit": config.queueLimit,
    });
};

let getUsers =
  Sihl.Core.Http.endpoint({
    verb: GET,
    path: "/",
    handler: _req => {
      let pool =
        Sihl.Core.Error.Decco.stringifyDecoder(Sihl.Core.Config.Db.read, ())
        ->Belt.Result.map(Database.pool)
        ->Sihl.Core.Db.failIfError;
      let%Async db = Sihl.Core.Db.Pool.connect(pool);
      let%Async users = Repository.User.GetAll.query(db);
      let response = users |> Repository.RepoResult.rows |> Model.Users.encode;
      Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
    },
  });

let getUser =
  Sihl.Core.Http.endpoint({
    verb: GET,
    path: "/:id/",
    handler: _req => {
      let pool =
        Sihl.Core.Error.Decco.stringifyDecoder(Sihl.Core.Config.Db.read, ())
        ->Belt.Result.map(Database.pool)
        ->Sihl.Core.Db.failIfError;
      let%Async db = Sihl.Core.Db.Pool.connect(pool);
      let%Async users = Repository.User.Get.query(db, ~userId="TODO");
      let response = users |> Model.User.encode;
      Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
    },
  });

/* let auth: Sihl.Core.Http.Middleware.t = */
/*   (handler, request) => { */
/*     open Tablecloth; */
/*     let isValidToken = */
/*       request */
/*       |> Sihl.Core.Http.Request.authToken */
/*       |> Option.map(~f=Sihl.Core.Jwt.isVerifyableToken(~secret="ABC")) */
/*       |> Option.withDefault(~default=false); */
/*     isValidToken */
/*       ? handler(request) */
/*       : Future.value( */
/*           Sihl.Core.Http.Response.errorToResponse( */
/*             `AuthenticationError("Not authenticated"), */
/*           ), */
/*         ); */
/*   }; */

/* Route.post("/register/", Routes.register), */
/* Route.get("/login/", Routes.login), */
/* Route.get("/", Routes.getUsers(pool) |> Routes.auth), */
/* Route.get("/:id/", Routes.getUser(pool) |> Routes.auth), */
/* Route.get("/me/", Routes.getMyUser |> Routes.auth), */
/* Route.post( */
/*   "/request-password-reset/", */
/*   Routes.requestPasswordReset |> Routes.auth, */
/* ), */
/* Route.post("/reset-password/", Routes.resetPassword |> Routes.auth), */
/* Route.post("/update-password/", Routes.updatePassword |> Routes.auth), */
/* Route.post("/set-password/", Routes.setPassword |> Routes.auth), */
