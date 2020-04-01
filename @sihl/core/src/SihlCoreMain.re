module Make = (Persistence: SihlCoreDb.PERSISTENCE) => {
  module Async = SihlCoreAsync;

  exception InvalidConfiguration(string);

  module SihlCoreHttp = SihlCoreHttp.Make(Persistence);
  module SihlCoreCli = SihlCoreCli.Make(Persistence);
  module SihlCoreMigration = SihlCoreMigration.Make(Persistence);

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
  };

  module Project = {
    type t = {
      environment: SihlCoreConfig.Environment.t,
      apps: list(App.t),
    };

    module RunningInstance = {
      type t = {
        configuration: SihlCoreConfig.Configuration.t,
        http: SihlCoreHttp.application,
        db: Persistence.Database.t,
        apps: list(App.t),
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

    let make = (~environment, apps) => {
      {environment, apps};
    };

    let runMigrations = (instance: RunningInstance.t) => {
      instance.apps
      ->Belt.List.map(app => app.migration)
      ->SihlCoreMigration.applyMigrations(instance.db);
    };

    let start = (project: t) => {
      let apps = project.apps;
      SihlCoreLog.info(
        "Starting project with apps: " ++ App.names(apps),
        (),
      );
      SihlCoreLog.info("Loading and validating project configuration", ());
      let configuration =
        switch (
          SihlCoreConfig.Environment.configuration(
            project.environment,
            Belt.List.map(project.apps, app => app.configurationSchema),
          )
        ) {
        | Ok(configuration) =>
          SihlCoreLog.info("Project configuration is valid", ());
          configuration;
        | Error(msg) =>
          let msg = "Project configuration is invalid: " ++ msg;
          SihlCoreLog.error(msg, ());
          raise(InvalidConfiguration(msg));
        };
      let db =
        SihlCoreConfig.Db.Url.readFromEnv() |> Persistence.Database.setup;
      SihlCoreLog.info("Mounting HTTP routes", ());
      let routes =
        apps
        ->Belt.List.map(app => app.routes(db))
        ->Belt.List.toArray
        ->Belt.List.concatMany;
      let http = SihlCoreHttp.application(routes);
      RunningInstance.make(~configuration, ~http, ~db, ~apps);
    };

    let stop = (instance: RunningInstance.t) => {
      SihlCoreLog.info("Stopping apps: " ++ App.names(instance.apps), ());
      let%Async _ = SihlCoreHttp.shutdown(instance.http);
      Async.async @@ Persistence.Database.end_(instance.db);
    };
  };

  module Manager = {
    exception InvalidState(string);

    let state = ref(None);

    let start = (project: Project.t) => {
      if (Belt.Option.isSome(state^)) {
        raise(
          InvalidState("There is already an app running, can not start"),
        );
      };
      let project = Project.start(project);
      state := Some(project);
      // TODO this might get out of sync
      SihlCoreConfig.configuration := Some(project.configuration);
      Project.runMigrations(project)->Async.mapAsync(_ => project);
    };

    let stop = () => {
      switch (state^) {
      | Some(instance) =>
        // TODO this might get out of sync
        SihlCoreConfig.configuration := None;
        Project.stop(instance)->Async.mapAsync(_ => {state := None});
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

    let start: Project.t => command =
      project => {
        name: "start",
        description: "start",
        f: (_, args, description) => {
          switch (args) {
          | ["start", ..._] =>
            Manager.start(project)->Async.mapAsync(_ => ())
          | _ => Async.async(Js.log("Usage: " ++ description))
          };
        },
      };

    let register = (commands: list(SihlCoreCli.command), project) => {
      let defaultCommands = [version, start(project)];
      commands
      ->Belt.List.concat(defaultCommands)
      ->Belt.List.map(command => (command.name, command))
      ->Js.Dict.fromList;
    };

    let execute = (project: Project.t, args) => {
      let commands =
        project.apps
        ->Belt.List.map(app => app.commands)
        ->Belt.List.toArray
        ->Belt.List.concatMany
        ->register(project);
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
      let setupHarness = (project: Project.t) => {
        Node.Process.putEnvVar("SIHL_ENV", "test");
        beforeAllPromise(_ => Manager.start(project));
        beforeEachPromise(_ => Manager.clean());
        afterAllPromise(_ => Manager.stop());
      };
    };
  };
};
