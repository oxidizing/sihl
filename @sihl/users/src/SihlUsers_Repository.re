module Sihl = SihlUsers_Sihl;
module Async = Sihl.Core.Async;
module Model = SihlUsers_Model;

module User = {
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
      Sihl.Core.Repo.Connection.t =>
      Async.t(Sihl.Core.Db.Result.Query.t(Model.User.t)) =
      connection =>
        Sihl.Core.Repo.getMany(
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
      (Sihl.Core.Repo.Connection.t, ~userId: string) =>
      Async.t(Belt.Result.t(Model.User.t, string)) = {
      (connection, ~userId) =>
        Sihl.Core.Repo.getOne(
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
      (Sihl.Core.Repo.Connection.t, ~email: string) =>
      Async.t(Belt.Result.t(Model.User.t, string)) =
      (connection, ~email) =>
        Sihl.Core.Repo.getOne(
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
      Sihl.Core.Repo.execute(
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
      Sihl.Core.Repo.execute(
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
      (Sihl.Core.Repo.Connection.t, ~token: string) =>
      Async.t(Belt.Result.t(Model.Token.t, string)) =
      (connection, ~token) =>
        Sihl.Core.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(token),
          ~decode=Model.Token.t_decode,
          (),
        );
  };

  module DeleteForUser = {
    let stmt = "
DELETE users_tokens
FROM users_tokens
LEFT JOIN users_users
ON users_users.id = users_tokens.user
WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))
AND users_tokens.kind LIKE ?;
";

    [@decco]
    type parameters = (string, string);

    let query = (connection, ~userId: string, ~kind: string) => {
      Sihl.Core.Repo.execute(
        ~parameters=parameters_encode((userId, kind)),
        connection,
        stmt,
      );
    };
  };
};
