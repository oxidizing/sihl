module Log = SihlCore_Log;
module Config = SihlCore_Config;
module Async = SihlCore_Async;
module Http = SihlCore_Http;
module Db = SihlCore_Db;

// TODO centralize
exception InvalidConfiguration(string);

module App = {
  type t('d, 'c, 'm) =
    SihlCore_App.t(
      Db.database('d, 'c, 'm),
      SihlCore_Http_Core.endpoint,
      SihlCore_Cli_Core.command(Db.database('d, 'c, 'm)),
    );

  let names = (apps: list(t('d, 'c, 'm))) =>
    Js.Array.joinWith(
      ", ",
      apps->Belt.List.map(app => app.namespace)->Belt.List.toArray,
    );

  let make =
      (
        ~name,
        ~namespace,
        ~routes,
        ~migration,
        ~commands,
        ~configurationSchema,
      )
      : t('d, 'c, 'm) => {
    name,
    namespace,
    routes,
    migration,
    commands,
    configurationSchema,
  };
};

module Project = {
  type t('d, 'c, 'm) = {
    environment: Config.Environment.t,
    apps: list(App.t('d, 'c, 'm)),
    persistence: Db.persistence('d, 'c, 'm),
  };

  let make = (persistence, ~environment, apps) => {
    {environment, apps, persistence};
  };

  module RunningInstance = {
    type t('d, 'c, 'm) = {
      configuration: Config.Configuration.t,
      http: Http.application,
      db: Db.database('d, 'c, 'm),
      apps: list(App.t('d, 'c, 'm)),
    };
    let http = instance => instance.http;
    let db = instance => instance.db;
    let make = (~configuration, ~http, ~db, ~apps) => {
      configuration,
      http,
      db,
      apps,
    };
  };

  let runMigrations = (instance: RunningInstance.t('d, 'c, 'm)) => {
    let migrations = instance.apps->Belt.List.map(app => app.migration);
    SihlCore_Migration.applyMigrations(instance.db, migrations);
  };

  let start = (project: t('d, 'c, 'm)) => {
    let apps = project.apps;
    Log.info("Starting project with apps: " ++ App.names(apps), ());
    Log.info("Loading and validating project configuration", ());
    let configuration =
      switch (
        Config.Environment.configuration(
          project.environment,
          Belt.List.map(project.apps, app => app.configurationSchema),
        )
      ) {
      | Ok(configuration) =>
        Log.info("Project configuration is valid", ());
        configuration;
      | Error(msg) =>
        let msg = "Project configuration is invalid: " ++ msg;
        Log.error(msg, ());
        raise(InvalidConfiguration(msg));
      };
    let%Async db = Config.Db.Url.readFromEnv() |> project.persistence.setup;
    Log.info("Mounting HTTP routes", ());
    let routes =
      apps
      ->Belt.List.map(app => app.routes(db))
      ->Belt.List.toArray
      ->Belt.List.concatMany;
    let http = Http.application(routes);
    Async.async @@ RunningInstance.make(~configuration, ~http, ~db, ~apps);
  };

  let stop = (instance: RunningInstance.t('d, 'c, 'm)) => {
    Log.info("Stopping apps: " ++ App.names(instance.apps), ());
    let%Async _ = Http.shutdown(instance.http);
    Async.async @@ instance.db.end_(instance.db.this);
  };
};

module Manager: {} = {
  // TODO centralize
  exception InvalidState(string);

  let state: Pervasives.ref(option(Project.RunningInstance.t('d, 'c, 'm))) =
    ref(None);

  let start = (project: Project.t('d, 'c, 'm)) => {
    if (Belt.Option.isSome(state^)) {
      raise(InvalidState("There is already an app running, can not start"));
    };
    let%Async project = Project.start(project);

    state := Some(project);
    // TODO this might get out of sync
    Config.configuration := Some(project.configuration);
    Project.runMigrations(project)->Async.mapAsync(_ => project);
  };

  let stop = () => {
    switch (state^) {
    | Some(instance) =>
      // TODO this might get out of sync
      Config.configuration := None;
      Project.stop(instance)->Async.mapAsync(_ => {state := None});
    | _ =>
      Log.warn(
        "Can not stop app because it was not started, ignoring stop",
        (),
      );
      Async.async();
    };
  };

  let seed = f => {
    switch (state^) {
    | Some(instance) =>
      let%Async conn = instance.db.connect();
      let%Async result = f(conn);
      let%Async _ = conn.release(conn.this);
      Async.async(result);
    | _ =>
      Log.warn("Can not seed because app was not started", ());
      raise(InvalidState("Can not seed because app was not started"));
    };
  };

  let clean = () => {
    switch (state^) {
    | Some(instance) => instance.db.clean(instance.db.this)
    | _ =>
      Log.warn("Can not clean because app was not started", ());
      raise(InvalidState("Can not clean because app was not started"));
    };
  };
};

/* module Cli = { */
/*   module Cli = SihlCore_Cli; */
/*   type command = SihlCore_Cli_Core.command(Db.Connection.t); */

/*   let version: command = { */
/*     name: "version", */
/*     description: "version", */
/*     f: (_, args, description) => { */
/*       switch (args) { */
/*       | ["version", ..._] => Async.async(Js.log("Sihl v0.0.1")) */
/*       | _ => Async.async(Js.log("Usage: sihl " ++ description)) */
/*       }; */
/*     }, */
/*   }; */

/*   let start: Project.t => command = */
/*     project => { */
/*       name: "start", */
/*       description: "start", */
/*       f: (_, args, description) => { */
/*         switch (args) { */
/*         | ["start", ..._] => Manager.start(project)->Async.mapAsync(_ => ()) */
/*         | _ => Async.async(Js.log("Usage: " ++ description)) */
/*         }; */
/*       }, */
/*     }; */

/*   let register = (commands: list(Cli.command), project) => { */
/*     let defaultCommands = [version, start(project)]; */
/*     commands */
/*     ->Belt.List.concat(defaultCommands) */
/*     ->Belt.List.map(command => (command.name, command)) */
/*     ->Js.Dict.fromList; */
/*   }; */

/*   let execute = (project: Project.t, args) => { */
/*     let commands = */
/*       project.apps */
/*       ->Belt.List.map(app => app.commands) */
/*       ->Belt.List.toArray */
/*       ->Belt.List.concatMany */
/*       ->register(project); */
/*     let args = Cli.trimArgs(args, "sihl"); */
/*     let commandName = args->Belt.List.head->Belt.Option.getExn; */
/*     switch (Cli.getCommand(commands, commandName)) { */
/*     | exception (Cli.InvalidCommandException(msg)) => */
/*       Async.async(Js.log(msg)) */
/*     | command => */
/*       let Project.{persistence: (module P)} = project; */
/*       Cli.runCommand((module P), command, args); */
/*     }; */
/*   }; */
/* }; */

/* module Test = { */
/*   module Integration = { */
/*     open Jest; */
/*     [%raw "require('isomorphic-fetch')"]; */
/*     let setupHarness = (project: Project.t('d, 'c, 'm)) => { */
/*       Node.Process.putEnvVar("SIHL_ENV", "test"); */
/*       beforeAllPromise(_ => Manager.start(project)); */
/*       beforeEachPromise(_ => Manager.clean()); */
/*       afterAllPromise(_ => Manager.stop()); */
/*     }; */
/*   }; */
/* }; */
