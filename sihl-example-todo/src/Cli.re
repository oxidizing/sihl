module Async = Sihl.Core.Async;

let version: Sihl.Core.Cli.command = {
  name: "version",
  description: "version",
  f: (_, args, description) => {
    switch (args) {
    | ["version", ..._] => Async.async(Js.log("Sihl v0.0.1"))
    | _ => Async.async(Js.log("Usage: " ++ description))
    };
  },
};

let createAdmin: Sihl.Core.Cli.command = {
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

let commands = Sihl.Core.Cli.registerCommands([version, createAdmin]);
Sihl.Core.Cli.execute(commands, Node.Process.argv);
