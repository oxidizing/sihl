module Async = Common_Async;

module Make = (Persistence: Common_Db.PERSISTENCE) => {
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

  type command = Common_Http.command(Persistence.Connection.t);

  let runCommand = (command: command, args) => {
    let%Async db =
      Common_Config.Db.Url.readFromEnv() |> Persistence.Database.setup;
    let%Async _ =
      Persistence.Database.withConnection(db, conn =>
        Async.catchAsync(command.f(conn, args, command.description), err =>
          Async.async(Js.log2("Failed to run command: ", err))
        )
      );
    Persistence.Database.end_(db);
  };

  let printCommands = commands => {
    Js.log("These are all supported commands:");
    Js.log("---------------------------------");
    commands
    ->Js.Dict.values
    ->Belt.Array.forEach((command: command) =>
        Js.log("sihl " ++ command.description)
      );
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
