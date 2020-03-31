module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module Async = SihlCoreAsync;

  exception InvalidConfiguration(string);

  module SihlCoreHttp = SihlCoreHttp.Make(Persistence);
  module SihlCoreCli = SihlCoreCli.Make(Persistence);
  module SihlCoreDb = SihlCoreDb.Make(Persistence);

  module App = {
    type t =
      SihlCoreApp.t(
        Persistence.Database.t,
        SihlCoreHttpCore.endpoint,
        SihlCoreHttpCore.command(Persistence.Connection.t),
      );

    let names = (apps: list(t)) =>
      Js.Array.joinWith(
        ", ",
        apps->Belt.List.map(app => app.namespace)->Belt.List.toArray,
      );

    module Instance = {
      type app = t;
      type t = {
        http: SihlCoreHttp.application,
        db: Persistence.Database.t,
        apps: list(app),
      };
      let http = instance => instance.http;
      let db = instance => instance.db;
      let make = (~http, ~db, ~apps) => {http, db, apps};
    };

    let db = instance => Instance.db(instance);

    let make =
        (
          ~name,
          ~namespace,
          ~routes,
          ~migration,
          ~commands,
          ~configurationSchema,
        )
        : t => {
      name,
      namespace,
      routes,
      migration,
      commands,
      configurationSchema,
    };

    let runMigrations = (instance: Instance.t) => {
      instance.apps
      ->Belt.List.map(app => app.migration)
      ->SihlCoreDb.Migration.applyMigrations(instance.db);
    };

    let startApps = (~environment, apps: list(t)) => {
      // TODO
      // get current SIHL_ENV
      // merge configuration schemas per app => configurationSchema
      // merge (environment vars, app1 env, app2 env, ...) => configuration
      // validate(configuration, configurationSchema)
      // store config in state
      SihlCoreLog.info("Starting apps: " ++ names(apps), ());
      let db =
        SihlCoreConfig.Db.Url.readFromEnv() |> Persistence.Database.setup;
      SihlCoreLog.info("Mounting HTTP routes", ());
      let routes =
        apps
        ->Belt.List.map(app => app.routes(db))
        ->Belt.List.toArray
        ->Belt.List.concatMany;
      let http = SihlCoreHttp.application(routes);
      Instance.make(~http, ~db, ~apps);
    };

    let stop = (instance: Instance.t) => {
      SihlCoreLog.info("Stopping apps: " ++ names(instance.apps), ());
      let%Async _ = SihlCoreHttp.shutdown(instance.http);
      Async.async @@ Persistence.Database.end_(instance.db);
    };
  };

  module Manager = {
    exception InvalidState(string);

    let state = ref(None);

    let startApps = (~environment, apps: list(App.t)) => {
      if (Belt.Option.isSome(state^)) {
        raise(
          InvalidState("There is already an app running, can not start"),
        );
      };
      let app = App.startApps(~environment, apps);
      state := Some(app);
      App.runMigrations(app)->Async.mapAsync(_ => app);
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
        Persistence.Database.withConnection(instance.db, conn => f(conn))
      | _ =>
        SihlCoreLog.warn("Can not seed because app was not started", ());
        raise(InvalidState("Can not seed because app was not started"));
      };
    };

    let clean = () => {
      switch (state^) {
      | Some(instance) => Persistence.Database.clean(instance.db)
      | _ =>
        SihlCoreLog.warn("Can not clean because app was not started", ());
        raise(InvalidState("Can not clean because app was not started"));
      };
    };
  };

  type command = SihlCoreHttpCore.command(Persistence.Connection.t);

  module Cli = {
    open! SihlCoreCli;
    let version: command = {
      name: "version",
      description: "version",
      f: (_, args, description) => {
        switch (args) {
        | ["version", ..._] => Async.async(Js.log("Sihl v0.0.1"))
        | _ => Async.async(Js.log("Usage: sihl " ++ description))
        };
      },
    };

    let start: list(App.t) => command =
      apps => {
        name: "start",
        description: "start",
        f: (_, args, description) => {
          switch (args) {
          | ["start", ..._] =>
            // TODO load proper environment
            Manager.startApps(~environment=[], apps)->Async.mapAsync(_ => ())
          | _ => Async.async(Js.log("Usage: " ++ description))
          };
        },
      };

    let register = (commands: list(SihlCoreCli.command), apps) => {
      let defaultCommands = [version, start(apps)];
      commands
      ->Belt.List.concat(defaultCommands)
      ->Belt.List.map(command => (command.name, command))
      ->Js.Dict.fromList;
    };

    let execute = (apps: list(App.t), args) => {
      let commands =
        apps
        ->Belt.List.map(app => app.commands)
        ->Belt.List.toArray
        ->Belt.List.concatMany
        ->register(apps);
      let args = SihlCoreCli.trimArgs(args, "sihl");
      let commandName = args->Belt.List.head->Belt.Option.getExn;
      switch (SihlCoreCli.getCommand(commands, commandName)) {
      | exception (SihlCoreCli.InvalidCommandException(msg)) =>
        Async.async(Js.log(msg))
      | command => SihlCoreCli.runCommand(command, args)
      };
    };
  };

  module Test = {
    module Async = SihlCoreAsync;
    module Integration = {
      open Jest;
      [%raw "require('isomorphic-fetch')"];
      let setupHarness = apps => {
        // TODO load proper environment
        beforeAllPromise(_ => Manager.startApps(~environment=[], apps));
        beforeEachPromise(_ => Manager.clean());
        afterAllPromise(_ => Manager.stop());
      };
    };
  };
};
