module Async = Sihl.Core.Async;

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
  f: (Sihl.Core.Db.Connection.t, list(string), string) => Js.Promise.t(unit),
};

let runCommand = (command, args) => {
  let config = Sihl.Core.Main.App.readConfig();
  let db = Sihl.Core.Main.App.connectDatabase(config);
  let%Async _ =
    Sihl.Core.Db.Database.withConnection(db, conn =>
      Async.catchAsync(command.f(conn, args, command.description), err =>
        Async.async(Js.log2("Failed to run command: ", err))
      )
    );
  Async.async(Sihl.Core.Db.Database.end_(db));
};

let version: command = {
  name: "version",
  description: "version",
  f: (_, args, description) => {
    switch (args) {
    | ["version", ..._] => Async.async(Js.log("Sihl v0.0.1"))
    | _ => Async.async(Js.log("Usage: " ++ description))
    };
  },
};

let createAdmin: command = {
  name: "createadmin",
  description: "createadmin <username> <email> <password>",
  f: (conn, args, description) => {
    switch (args) {
    | ["createadmin", username, email, password, ..._] =>
      Sihl.Users.User.createAdmin(
        conn,
        ~username,
        ~givenName="Admin",
        ~familyName="Admin",
        ~email,
        ~password,
      )
      ->Async.mapAsync(_ => Js.log("Created admin " ++ email))
    | _ => Async.async(Js.log("Usage: " ++ description))
    };
  },
};

let getWithDefaultF = (o, f) => {
  switch (o) {
  | Some(o) => o
  | None => f()
  };
};

let registerCommands = commands => {
  commands
  ->Belt.List.map(command => (command.name, command))
  ->Js.Dict.fromList;
};

let commands = registerCommands([version, createAdmin]);

let printCommands = commands => {
  Js.log("These are all supported commands:");
  Js.log("---------------------------------");
  commands
  ->Js.Dict.values
  ->Belt.Array.forEach(command => Js.log(command.description));
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

let execute = (commands, args) => {
  let args = trimArgs(args, "sihl");
  let commandName = args->Belt.List.head->Belt.Option.getExn;
  switch (getCommand(commands, commandName)) {
  | exception (InvalidCommandException(msg)) => Async.async(Js.log(msg))
  | command => runCommand(command, args)
  };
};

execute(commands, Node.Process.argv);
