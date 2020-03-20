module Async = Sihl.Core.Async;

module User = {
  let Sihl.Core.Db.Crud.{clean, getAll, get, upsert} =
    Sihl.Core.Db.Crud.makeRepos(Model.User.meta);

  let getByEmailStmt = "
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

  let getByEmail:
    (Sihl.Core.Db.Connection.t, ~email: string) =>
    Js.Promise.t(Belt.Result.t(Model.User.t, string)) =
    (connection, ~email) =>
      Sihl.Core.Db.Repo.getOne(
        ~connection,
        ~stmt=getByEmailStmt,
        ~parameters=Js.Json.string(email),
        ~decode=Model.User.t_decode,
        (),
      );
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
      Sihl.Core.Db.Repo.execute(
        ~parameters=parameters_encode((userId, kind)),
        connection,
        stmt,
      );
    };
  };
};
