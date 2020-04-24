module Sihl = SihlUsers_Sihl;
module Async = Sihl.Core.Async;
module Service = SihlUsers_Service;

let admin = conn =>
  Service.User.createAdmin(
    conn,
    ~email="admin@example.com",
    ~username="admin",
    ~password="password",
    ~givenName="Admin",
    ~familyName="Admin",
  );

let loggedInAdmin = conn => {
  let%Async _ =
    Service.User.createAdmin(
      conn,
      ~email="admin@example.com",
      ~username="admin",
      ~password="password",
      ~givenName="Admin",
      ~familyName="Admin",
    );
  Service.User.login(conn, ~email="admin@example.com", ~password="password");
};

let user = (email, password, conn) =>
  Service.User.register(
    conn,
    ~email,
    ~password,
    ~username="foobar",
    ~givenName="Foo",
    ~familyName="Bar",
    ~phone=None,
    ~suppressEmail=true,
    (),
  );

let loggedInUser = (email, password, conn) => {
  let%Async _ =
    Service.User.register(
      conn,
      ~email,
      ~password,
      ~username="foobar",
      ~givenName="Foo",
      ~familyName="Bar",
      ~phone=None,
      ~suppressEmail=true,
      (),
    );
  Service.User.login(conn, ~email, ~password);
};
