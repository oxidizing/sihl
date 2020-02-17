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
  status
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
  status
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
  status
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
  status
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
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
      Js.Json.t,
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
            user.status |> Model.Status.t_encode,
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
  users
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  (SELECT id FROM users_users WHERE users.uuid = UNHEX(REPLACE(?, '-', '')))
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

module Permission = {
  module Clean = {
    let stmt_users_permissions = "
TRUNCATE TABLE users_permissions;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = {
      connection => {
        Sihl.Core.Db.Repo.execute(connection, stmt_users_permissions);
      };
    };
  };

  module Has = {
    let stmt = "
SELECT
  uuid_of(uuid) as uuid,
  user,
  permission
FROM users_users_permissions
WHERE user = (SELECT id FROM users WHERE uuid = UNHEX(REPLACE(?, '-', '')))
AND permission = ?;
";

    [@decco]
    type parameters = (string, string);

    [@decco]
    type result = {
      uuid: string,
      user: int,
      permission: string,
    };

    let query = (connection, ~user: Model.User.t, ~perm: string) => {
      Sihl.Core.Db.Repo.getOne(
        ~connection,
        ~parameters=parameters_encode((user.id, perm)),
        ~stmt,
        ~decode=result_decode,
        (),
      )
      ->Async.mapAsync(_ => true);
    };
  };

  /*  module Store = { */
  /*     let stmt = " */
         /* INSERT INTO users_permissions ( */
         /*   uuid, */
         /*   name */
         /* ) VALUES ( */
         /*   UNHEX(REPLACE(?, '-', '')), */
         /*   ? */
         /* ); */
         /* "; */

  /*     [@decco] */
  /*     type parameters = (string, string); */

  /*     let query = (connection, ~permission: Model.Permission.t) => */
  /*       Sihl.Core.Db.Repo.execute( */
  /*         ~parameters=parameters_encode((permission.id, permission.name)), */
  /*         connection, */
  /*         stmt, */
  /*       ); */
  /*   }; */

  module Assign = {
    let stmt = "
INSERT INTO users_users_permissions (
  uuid,
  user,
  permission
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  (SELECT id FROM users_users WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))),
  ?
);
";

    [@decco]
    type parameters = (string, string);

    let query = (connection, ~user: Model.User.t, ~perm: Model.Permission.t) =>
      Sihl.Core.Db.Repo.execute(
        ~parameters=parameters_encode((user.id, perm.id)),
        connection,
        stmt,
      );
  };
};
