exception InvalidConfiguration(string);

module App = {
  type t = {
    name: string,
    namespace: string,
    routes: SihlCoreDb.Database.t => list(SihlCoreHttp.Endpoint.endpoint),
    clean: list(SihlCoreDb.Connection.t => Js.Promise.t(unit)),
    migrations: unit => list(string),
  };

  module Instance = {
    type instance = {
      http: SihlCoreHttp.application,
      db: SihlCoreDb.Database.t,
      app: t,
    };
    let http = instance => instance.http;
    let db = instance => instance.db;
    let make = (~http, ~db, ~app) => {http, db, app};
  };

  let db = instance => Instance.db(instance);

  let make = (~name, ~namespace, ~routes, ~clean, ~migrations) => {
    name,
    namespace,
    routes,
    clean,
    migrations,
  };

  let start = (app: t) => {
    // TODO catch all exceptions (ServerExceptions might get thrown)
    SihlCoreLog.info("Starting app " ++ app.name, ());
    let config =
      SihlCoreConfig.Db.read()
      |> SihlCoreError.Decco.stringifyResult
      |> SihlCoreError.failIfError;
    let db = config |> SihlCoreDb.Database.make;
    let routes = db |> app.routes;
    let http = SihlCoreHttp.application(~port=3000, routes);
    SihlCoreLog.info("App started on port 3000", ());
    Instance.make(~http, ~db, ~app);
  };

  let stop = (app: Instance.instance) => {
    module Async = SihlCoreAsync;
    SihlCoreLog.info("Stopping app " ++ app.app.name, ());
    let%Async _ = SihlCoreHttp.shutdown(app.http);
    Async.async @@ SihlCoreDb.Database.end_(app.db);
  };
};
