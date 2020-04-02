module Make = (Persistence: Common_Db.PERSISTENCE) => {
  module Async = Common_Async;

  exception InvalidConfiguration(string);

  module App_Http = App_Http.Make(Persistence);
  module App_Cli = App_Cli.Make(Persistence);
  module App_Migration = App_Migration.Make(Persistence);

  module App = {
    type t =
      App_App.t(
        Persistence.Database.t,
        Common_Http.endpoint,
        Common_Http.command(Persistence.Connection.t),
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
      environment: Common_Config.Environment.t,
      apps: list(App.t),
    };

    module RunningInstance = {
      type t = {
        configuration: Common_Config.Configuration.t,
        http: App_Http.application,
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
      ->App_Migration.applyMigrations(instance.db);
    };

    let start = (project: t) => {
      let apps = project.apps;
      Common_Log.info("Starting project with apps: " ++ App.names(apps), ());
      Common_Log.info("Loading and validating project configuration", ());
      let configuration =
        switch (
          Common_Config.Environment.configuration(
            project.environment,
            Belt.List.map(project.apps, app => app.configurationSchema),
          )
        ) {
        | Ok(configuration) =>
          Common_Log.info("Project configuration is valid", ());
          configuration;
        | Error(msg) =>
          let msg = "Project configuration is invalid: " ++ msg;
          Common_Log.error(msg, ());
          raise(InvalidConfiguration(msg));
        };
      let db =
        Common_Config.Db.Url.readFromEnv() |> Persistence.Database.setup;
      Common_Log.info("Mounting HTTP routes", ());
      let routes =
        apps
        ->Belt.List.map(app => app.routes(db))
        ->Belt.List.toArray
        ->Belt.List.concatMany;
      let http = App_Http.application(routes);
      RunningInstance.make(~configuration, ~http, ~db, ~apps);
    };

    let stop = (instance: RunningInstance.t) => {
      Common_Log.info("Stopping apps: " ++ App.names(instance.apps), ());
      let%Async _ = App_Http.shutdown(instance.http);
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
      Common_Config.configuration := Some(project.configuration);
      Project.runMigrations(project)->Async.mapAsync(_ => project);
    };

    let stop = () => {
      switch (state^) {
      | Some(instance) =>
        // TODO this might get out of sync
        Common_Config.configuration := None;
        Project.stop(instance)->Async.mapAsync(_ => {state := None});
      | _ =>
        Common_Log.warn(
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
        Common_Log.warn("Can not seed because app was not started", ());
        raise(InvalidState("Can not seed because app was not started"));
      };
    };

    let clean = () => {
      switch (state^) {
      | Some(instance) => Persistence.Database.clean(instance.db)
      | _ =>
        Common_Log.warn("Can not clean because app was not started", ());
        raise(InvalidState("Can not clean because app was not started"));
      };
    };
  };

  type command = Common_Http.command(Persistence.Connection.t);

  module Cli = {
    open! App_Cli;
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

    let register = (commands: list(App_Cli.command), project) => {
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
      let args = App_Cli.trimArgs(args, "sihl");
      let commandName = args->Belt.List.head->Belt.Option.getExn;
      switch (App_Cli.getCommand(commands, commandName)) {
      | exception (App_Cli.InvalidCommandException(msg)) =>
        Async.async(Js.log(msg))
      | command => App_Cli.runCommand(command, args)
      };
    };
  };

  module Test = {
    module Async = Common_Async;
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
