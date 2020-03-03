module Async = Sihl.Core.Async;

type t =
  | Admin
  | AdminOneUser;

let set = (db, seed) => {
  switch (seed) {
  | Admin =>
    Sihl.Core.Db.Database.withConnection(db, conn => {
      Service.User.createAdmin(
        conn,
        ~email="admin@example.com",
        ~username="admin",
        ~password="password",
        ~givenName="Admin",
        ~familyName="Admin",
      )
    })
  | AdminOneUser =>
    Sihl.Core.Db.Database.withConnection(
      db,
      conn => {
        let%Async _ =
          Service.User.createAdmin(
            conn,
            ~email="admin@example.com",
            ~username="admin",
            ~password="password",
            ~givenName="Admin",
            ~familyName="Admin",
          );
        Service.User.register(
          conn,
          ~email="foobar@example.com",
          ~password="123",
          ~username="foobar",
          ~givenName="Foo",
          ~familyName="Bar",
          ~phone=None,
          ~suppressEmail=true,
          (),
        );
      },
    )
  };
};
