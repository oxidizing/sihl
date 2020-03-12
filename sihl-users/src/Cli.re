module Async = Sihl.Core.Async;

let createAdmin: Sihl.Core.Cli.command = {
  name: "createadmin",
  description: "createadmin <username> <email> <password>",
  f: (conn, args, description) => {
    switch (args) {
    | ["createadmin", username, email, password, ..._] =>
      Service.User.createAdmin(
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
