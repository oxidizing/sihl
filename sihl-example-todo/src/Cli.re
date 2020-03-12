module Async = Sihl.Core.Async;

exception InvalidCommandException;

let cleanArgs = (args, command, usage) => {
  let args =
    args
    ->Belt.Array.getIndexBy(arg => arg === command)
    ->Belt.Option.map(idx =>
        args->Belt.Array.sliceToEnd(idx)->Belt.List.fromArray
      );
  switch (args) {
  | None =>
    Js.log(usage);
    raise(InvalidCommandException);
  | Some(args) => args
  };
};

let runCommand = f => {
  let config = Sihl.Core.Main.App.readConfig();
  let db = Sihl.Core.Main.App.connectDatabase(config);
  let%Async _ =
    Sihl.Core.Db.Database.withConnection(db, conn =>
      Async.catchAsync(f(conn), err =>
        Async.async(Js.log2("Failed to run command: ", err))
      )
    );
  Async.async(Sihl.Core.Db.Database.end_(db));
};

let createAdmin = conn => {
  let usage = "Usage: createadmin <username> <email> <password>";
  let args = cleanArgs(Node.Process.argv, "createadmin", usage);
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
  | _ => Async.async(Js.log(usage))
  };
};

runCommand(createAdmin);
