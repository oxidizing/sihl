# Issue management app

This issue management app showcases Sihl. It uses `sihl-users` for user management.

# Getting started

Start a local MariaDB instance. You can you `docker-compose` for that.

Run `yarn test` to run all integration tests.

Run `yarn start:server` to start the web server. The admin UI can be accessed at `http://localhost:3000/admin/login/`.

# Tutorial

This tutorial walks you through the code base step by step. Let's create an "Issue Management App" using Sihl.

Create a file `App.re` with following content:

```reasonml
let name = "Issue Management App";
let namespace = "issues";

let routes = database => [
];

let app = () =>
  Sihl.Core.Main.App.make(
    ~name,
    ~namespace,
    ~routes,
    ~clean=[],
    ~migration=Migrations.MariaDb.make(~namespace),
  );
```

## Data model

Let's start with the data model. A user should be able to create boards and he should be able to add issues to boards.

We want create following two MySQL tables that reflect the data model.

```SQL
CREATE TABLE issues_boards (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  owner BIGINT UNSIGNED,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY(owner) REFERENCES users_users(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

```SQL
CREATE TABLE issues_issues (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  description VARCHAR(512),
  board BIGINT UNSIGNED,
  assignee BIGINT UNSIGNED NULL,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (assignee) REFERENCES users_users(id),
  FOREIGN KEY (board) REFERENCES issues_boards(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Sihl takes care of migrations. Just create a file `Migrations.re` with following content:

```reasonml
module MariaDb = {
  let steps = namespace => [
    (
      1,
      {j|
CREATE TABLE $(namespace)_boards (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  owner BIGINT UNSIGNED,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY(owner) REFERENCES users_users(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    ),
    (
      2,
      {j|
CREATE TABLE $(namespace)_issues (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  description VARCHAR(512),
  board BIGINT UNSIGNED,
  assignee BIGINT UNSIGNED NULL,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (assignee) REFERENCES users_users(id),
  FOREIGN KEY (board) REFERENCES issues_boards(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    ),
  ];
  let make = (~namespace) => Sihl.Core.Db.Migration.{namespace, steps};
};
```

Notice how Sihl does the namespacing.

## HTTP Route

We want provide an HTTP endpoint for the client to fetch all boards of a user. Only authenticated users are allowed to use that route. The user has to be admin, otherwise he can only fetch his own boards.

Following ReasonML module reflects a GET route on `/issues/users/:userId/boards/`:

```reasonml
module GetBoardsByUser = {
  [@decco]
  type boards = list(Model.Board.t);

  [@decco]
  type params = {userId: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/users/:userId/boards/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Sihl.Users.User.authenticate(conn, token);
        let%Async {userId} = req.requireParams(params_decode);
        let%Async boards = Service.Board.getAllByUser((conn, user), ~userId);
        let response =
          boards |> Sihl.Core.Db.Repo.Result.rows |> boards_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
      },
    });
};
```

Sihl uses [decco](https://github.com/reasonml-labs/decco) to encode and decode types from and to JSON. Annotating a `type` t with `[@decco]` generates the functions `t_encode` and `t_decode` *at compile time*.

For the path we use string interpolation to set the proper root, which we have configured in `App.re` as the value `namespace`.

The handler is a function with that takes the database connection and the request and returns a response. We use `sihl-users` to perform user authentication and user authorization.
