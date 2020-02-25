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
  uuid_of(uuid) as id,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin,
  confirmed
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
    let stmt = "
SELECT
  uuid_of(uuid) as id,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin,
  confirmed
FROM users_users
WHERE uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Js.Promise.t(Belt.Result.t(Model.User.t, string)) = {
      (connection, ~userId) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(userId),
          ~decode=Model.User.t_decode,
          (),
        );
    };
  };

  module GetByEmail = {
    let stmt = "
SELECT
  uuid_of(uuid) as id,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status,
  admin,
  confirmed
FROM users_users
WHERE email = ?;
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~email: string) =>
      Js.Promise.t(Belt.Result.t(Model.User.t, string)) =
      (connection, ~email) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(email),
          ~decode=Model.User.t_decode,
          (),
        );
  };

  module Upsert = {
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
  admin,
  confirmed
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?
) ON DUPLICATE KEY UPDATE
email = VALUES(email),
password = VALUES(password),
given_name = VALUES(given_name),
family_name = VALUES(family_name),
username = VALUES(username),
phone = VALUES(phone),
status = VALUES(status),
admin = VALUES(admin),
confirmed = VALUES(confirmed)
;";

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
            user.confirmed,
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

  module Upsert = {
    let stmt = "
INSERT INTO users_tokens (
  uuid,
  token,
  user,
  status,
  kind
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  (SELECT id FROM users_users WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))),
  ?,
  ?
)
ON DUPLICATE KEY UPDATE
token = VALUES(token),
user = VALUES(user),
status = VALUES(status),
kind = VALUES(kind)
;";

    [@decco]
    type parameters = (string, string, string, string, string);

    let query = (connection, ~token: Model.Token.t) => {
      Sihl.Core.Db.Repo.execute(
        ~parameters=
          parameters_encode((
            token.id,
            token.token,
            token.user,
            token.status,
            token.kind,
          )),
        connection,
        stmt,
      );
    };
  };

  module Get = {
    let stmt = "
SELECT
  uuid_of(users_tokens.uuid) as id,
  uuid_of(users_users.uuid) as user,
  users_tokens.token as token,
  users_tokens.status as status,
  users_tokens.kind as kind
FROM users_tokens
LEFT JOIN users_users
ON users_users.id = users_tokens.user
WHERE token LIKE ?;
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~token: string) =>
      Js.Promise.t(Belt.Result.t(Model.Token.t, string)) =
      (connection, ~token) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(token),
          ~decode=Model.Token.t_decode,
          (),
        );
  };
};
