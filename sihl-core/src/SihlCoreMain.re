exception InvalidConfiguration(string);

module App = {
  type t = {
    name: string,
    namespace: string,
    routes: SihlCoreDb.Database.t => list(SihlCoreHttp.Endpoint.endpoint),
    clean: list(SihlCoreDb.Connection.t => Js.Promise.t(unit)),
    migration: SihlCoreDb.Migration.t,
  };

  let names = apps =>
    Js.Array.joinWith(
      ", ",
      apps->Belt.List.map(app => app.namespace)->Belt.List.toArray,
    );

  module Instance = {
    type instance = {
      http: SihlCoreHttp.application,
      db: SihlCoreDb.Database.t,
      apps: list(t),
    };
    let http = instance => instance.http;
    let db = instance => instance.db;
    let make = (~http, ~db, ~apps) => {http, db, apps};
  };

  let db = instance => Instance.db(instance);

  let make = (~name, ~namespace, ~routes, ~clean, ~migration) => {
    name,
    namespace,
    routes,
    clean,
    migration,
  };

  let readConfig = () =>
    SihlCoreConfig.Db.read()
    |> SihlCoreError.Decco.stringifyResult
    |> SihlCoreError.failIfError;

  let connectDatabase = config => config |> SihlCoreDb.Database.make;

  let runMigrations = (instance: Instance.instance) => {
    module Async = SihlCoreAsync;
    instance.apps
    ->Belt.List.map(app =>
        SihlCoreDb.Database.applyMigrations(app.migration, instance.db)
      )
    ->Async.allInOrder;
  };

  let startApps = (apps: list(t)) => {
    // TODO catch all exceptions (ServerExceptions might get thrown)
    SihlCoreLog.info("Starting apps: " ++ names(apps), ());
    let config = readConfig();
    let db = connectDatabase(config);
    SihlCoreLog.info("Mounting HTTP routes", ());
    let routes =
      apps
      ->Belt.List.map(app => app.routes(db))
      ->Belt.List.toArray
      ->Belt.List.concatMany;
    let http = SihlCoreHttp.application(~port=3000, routes);
    SihlCoreLog.info("App started on port 3000", ());
    Instance.make(~http, ~db, ~apps);
  };

  let stop = (instance: Instance.instance) => {
    module Async = SihlCoreAsync;
    SihlCoreLog.info("Stopping apps: " ++ names(instance.apps), ());
    let%Async _ = SihlCoreHttp.shutdown(instance.http);
    Async.async @@ SihlCoreDb.Database.end_(instance.db);
  };
};

module Manager = {
  exception InvalidState(string);

  module Async = SihlCoreAsync;
  let state = ref(None);

  let startApps = (apps: list(App.t)) => {
    if (Belt.Option.isSome(state^)) {
      raise(InvalidState("There is already an app running, can not start"));
    };
    let app = App.startApps(apps);
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

  let seed = f => {
    switch (state^) {
    | Some(instance) =>
      SihlCoreDb.Database.withConnection(instance.db, conn => f(conn))
    | _ =>
      SihlCoreLog.warn("Can not seed because app was not started", ());
      raise(InvalidState("Can not seed because app was not started"));
    };
  };

  let clean = () => {
    switch (state^) {
    | Some(instance) =>
      let cleanFns =
        instance.apps
        ->Belt.List.map(app => app.clean)
        ->Belt.List.toArray
        ->Belt.List.concatMany;
      SihlCoreDb.Database.clean(cleanFns, instance.db);
    | _ =>
      SihlCoreLog.warn("Can not clean because app was not started", ());
      raise(InvalidState("Can not clean because app was not started"));
    };
  };
};
