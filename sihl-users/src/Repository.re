module Async = Sihl.Core.Async;

module User = {
  module Clean = {
    let stmt = "
TRUNCATE TABLE users_users;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = {
      connection => Sihl.Core.Db.Repo.execute(connection, stmt);
    };
  };

  module GetAll = {
    let stmt = "
SELECT
  uuid_of(uuid) as uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin
FROM users_users;
";

    let query:
      Sihl.Core.Db.Connection.t =>
      Js.Promise.t(Sihl.Core.Db.Repo.Result.t(Model.User.t)) =
      connection =>
        Sihl.Core.Db.Repo.getMany(
          ~connection,
          ~stmt,
          ~decode=Model.User.t_decode,
          (),
        );
  };

  module Get = {
    let stmt = "SELECT
  uuid_of(uuid) as uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin
FROM users_users
WHERE uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Js.Promise.t(Model.User.t) =
      (connection, ~userId) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(userId),
          ~decode=Model.User.t_decode,
          (),
        );
  };

  module GetByEmail = {
    let stmt = "SELECT
  uuid_of(uuid) as uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin
FROM users_users
WHERE email = ?;
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~email: string) =>
      Js.Promise.t(Model.User.t) =
      (connection, ~email) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(email),
          ~decode=Model.User.t_decode,
          (),
        );
  };

  module Store = {
    let stmt = "
INSERT INTO users_users (
  uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?
);
";

    [@decco]
    type parameters = (
      string,
      string,
      string,
      string,
      string,
      string,
      option(string),
      string,
      bool,
    );

    let query = (connection, ~user: Model.User.t) =>
      Sihl.Core.Db.Repo.execute(
        ~parameters=
          parameters_encode((
            user.id,
            user.email,
            user.password,
            user.givenName,
            user.familyName,
            user.username,
            user.phone,
            user.status,
            user.admin,
          )),
        connection,
        stmt,
      );
  };
};

module Token = {
  module Clean = {
    let stmt = "
TRUNCATE TABLE users_tokens;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = {
      connection => Sihl.Core.Db.Repo.execute(connection, stmt);
    };
  };

  module Store = {
    let stmt = "
INSERT INTO users_tokens (
  uuid,
  token,
  user
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  (SELECT id FROM users_users WHERE users_users.uuid = UNHEX(REPLACE(?, '-', '')))
);
";

    [@decco]
    type parameters = (string, string, string);

    let query = (connection, ~token: Model.Token.t) =>
      Sihl.Core.Db.Repo.execute(
        ~parameters=parameters_encode((token.id, token.userId, token.token)),
        connection,
        stmt,
      );
  };

  module Get = {
    let stmt = "
SELECT
  uuid_of(uuid) as uuid,
  userId,
  token
FROM users_tokens
WHERE token = ?;
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~tokenString: string) =>
      Js.Promise.t(Model.Token.t) =
      (connection, ~tokenString) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(tokenString),
          ~decode=Model.Token.t_decode,
          (),
        );
  };
};
