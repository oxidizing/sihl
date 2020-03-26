module Async = SihlCoreAsync;

module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module SihlCoreDb = SihlCoreDb.Make(Persistence);

  exception InvalidCommandException(string);
  let trimArgs = (args, command) => {
    let args =
      args
      ->Belt.Array.getIndexBy(arg => arg === command)
      ->Belt.Option.map(idx =>
          args->Belt.Array.sliceToEnd(idx + 1)->Belt.List.fromArray
        );
    switch (args) {
    | None =>
      let msg = "Command not found: " ++ command;
      Js.log(msg);
      raise(InvalidCommandException(msg));
    | Some(args) => args
    };
  };

  type command = {
    name: string,
    description: string,
    f:
      (Persistence.Connection.t, list(string), string) => Js.Promise.t(unit),
  };

  let runCommand = (command, args) => {
    let db = SihlCoreDb.Database.connectWithCfg();
    let%Async _ =
      SihlCoreDb.Database.withConnection(db, conn =>
        Async.catchAsync(command.f(conn, args, command.description), err =>
          Async.async(Js.log2("Failed to run command: ", err))
        )
      );
    Async.async(Persistence.Database.end_(db));
  };

  let printCommands = commands => {
    Js.log("These are all supported commands:");
    Js.log("---------------------------------");
    commands
    ->Js.Dict.values
    ->Belt.Array.forEach(command => Js.log("sihl " ++ command.description));
    Js.log("---------------------------------");
  };

  let getCommand = (commands, commandName) => {
    switch (Js.Dict.get(commands, commandName)) {
    | None =>
      let msg = "Unsupported command provided: " ++ commandName;
      printCommands(commands);
      raise(InvalidCommandException(msg));
    | Some(command) => command
    };
  };
};
