exception InvalidConfiguration(string);

module App = {
  type t = {
    name: string,
    namespace: string,
    routes: SihlCoreDb.Database.t => list(SihlCoreHttp.Endpoint.endpoint),
    clean: list(SihlCoreDb.Connection.t => Js.Promise.t(unit)),
    migrations: string => list(string),
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

  let readConfig = () =>
    SihlCoreConfig.Db.read()
    |> SihlCoreError.Decco.stringifyResult
    |> SihlCoreError.failIfError;

  let connectDatabase = config => config |> SihlCoreDb.Database.make;

  let runMigrations = (instance: Instance.instance) =>
    SihlCoreDb.Database.runMigrations(
      instance.app.namespace,
      instance.app.migrations,
      instance.db,
    );

  let startHttpServer = (routes, db) => {
    let routes = db |> routes;
    SihlCoreHttp.application(~port=3000, routes);
  };

  let start = (app: t) => {
    // TODO catch all exceptions (ServerExceptions might get thrown)
    SihlCoreLog.info("Starting app " ++ app.name, ());
    let config = readConfig();
    let db = connectDatabase(config);
    let http = startHttpServer(app.routes, db);
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

module Manager = {
  exception InvalidState(string);

  module Async = SihlCoreAsync;
  let state = ref(None);

  let start = (app: App.t) => {
    if (Belt.Option.isSome(state^)) {
      raise(InvalidState("There is already an app running, can not start"));
    };
    let app = App.start(app);
    state := Some(app);
    App.runMigrations(app);
  };

  let stop = () => {
    switch (state^) {
    | Some(instance) =>
      App.stop(instance)->Async.mapAsync(_ => {state := None})
    | _ =>
      SihlCoreLog.warn(
        "Can not stop app because it was not started, ignoring stop",
        (),
      );
      Async.async();
    };
  };

  let seed = (seedSetter, seed) => {
    switch (state^) {
    | Some(instance) => seedSetter(instance.db, seed)
    | _ =>
      SihlCoreLog.warn("Can not seed because app was not started", ());
      raise(InvalidState("Can not seed because app was not started"));
    };
  };

  let clean = () => {
    switch (state^) {
    | Some(instance) =>
      SihlCoreDb.Database.clean(instance.app.clean, instance.db)
    | _ =>
      SihlCoreLog.warn("Can not clean because app was not started", ());
      raise(InvalidState("Can not clean because app was not started"));
    };
  };
};
