module Async = Sihl.Core.Async;

let jsonValues: (Js.Json.t, array(string)) => Js.Json.t = [%raw
  {|
(obj, fields) => fields.map(field => obj[field])
  |}
];

type crudRepo('a) = {
  clean: Sihl.Core.Db.Connection.t => Js.Promise.t(unit),
  getAll:
    Sihl.Core.Db.Connection.t => Js.Promise.t(Sihl.Core.Db.Repo.Result.t('a)),
  get:
    (Sihl.Core.Db.Connection.t, ~id: string) =>
    Js.Promise.t(Belt.Result.t('a, string)),
  upsert: (Sihl.Core.Db.Connection.t, ~entity: 'a) => Js.Promise.t(unit),
};

let makeCrudRepo: Model.meta('a) => crudRepo('a) =
  (meta: Model.meta('a)) => {
    let fields = Js.Array.joinWith(", ", Belt.List.toArray(meta.fields));
    let namespace = meta.namespace;
    let resource = meta.resource;
    let getAllStmt = {j|
SELECT
  uuid_of(uuid) as id,
  $(fields)
FROM $(namespace)_$(resource);
|j};
    let getStmt = {j|
SELECT
  uuid_of(uuid) as id,
  $(fields)
FROM $(namespace)_$(resource)
WHERE uuid = UNHEX(REPLACE(?, '-', ''));
|j};
    let freeVarsStmt =
      Js.Array.joinWith(
        ",\n",
        meta.fields->Belt.List.map(_ => "?")->Belt.List.toArray,
      );
    let onDuplicateStmt =
      Js.Array.joinWith(
        ",\n",
        meta.fields
        ->Belt.List.map(field => {j|$(field) = VALUES($(field))|j})
        ->Belt.List.toArray,
      );

    let upsertStmt = {j|
INSERT INTO $(namespace)_$(resource) (
  uuid,
  $(fields)
) VALUES (
UNHEX(REPLACE(?, '-', '')),
$(freeVarsStmt)
) ON DUPLICATE KEY UPDATE
$(onDuplicateStmt)
;
|j};
    let cleanStmt = {j|
TRUNCATE TABLE $(namespace)_$(resource);
     |j};

    {
      clean: connection => Sihl.Core.Db.Repo.execute(connection, cleanStmt),
      getAll: connection =>
        Sihl.Core.Db.Repo.getMany(
          ~connection,
          ~stmt=getAllStmt,
          ~decode=meta.decode,
          (),
        ),
      get: (connection, ~id) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt=getStmt,
          ~parameters=Js.Json.string(id),
          ~decode=meta.decode,
          (),
        ),
      upsert: (connection, ~entity: 'a) => {
        let insertFields =
          Belt.List.concat(["id"], meta.fields)->Belt.List.toArray;
        let parameters = jsonValues(meta.encode(entity), insertFields);
        Sihl.Core.Db.Repo.execute(~parameters, connection, upsertStmt);
      },
    };
  };

let {clean, getAll, get, upsert} = makeCrudRepo(Model.User.meta);

module User = {
  module Clean = {
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = clean;
  };

  module GetAll = {
    let query:
      Sihl.Core.Db.Connection.t =>
      Js.Promise.t(Sihl.Core.Db.Repo.Result.t(Model.User.t)) = getAll;
  };

  module Get = {
    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Js.Promise.t(Belt.Result.t(Model.User.t, string)) =
      (conn, ~userId) => get(conn, ~id=userId);
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
    let query = (connection, ~user: Model.User.t) =>
      upsert(connection, ~entity=user);
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
