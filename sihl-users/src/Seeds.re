module Async = Sihl.Core.Async;

let admin = conn =>
  Service.User.createAdmin(
    conn,
    ~email="admin@example.com",
    ~username="admin",
    ~password="password",
    ~givenName="Admin",
    ~familyName="Admin",
  );

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
