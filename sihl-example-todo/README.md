# Issue management app

This issue management app showcases Sihl. It uses `sihl-users` for user management.

## Getting started

Start a local MariaDB instance. You can you `docker-compose` for that.

Run `yarn test` to run all integration tests.

Run `yarn start:server` to start the web server. The admin UI can be accessed at `http://localhost:3000/admin/login/`.

## Tutorial

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

### Data model

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

Notice how Sihl takes care of the namespacing.

### Model

A model encapsulates business types and business logic. We need one model for the *issue* and one for the *board* to reflect both tables. Create a file `Model.re`:

```reasonml
module Issue = {
  [@decco]
  type t = {
    id: string,
    title: string,
    description: option(string),
    board: string,
    assignee: option(string),
    status: string,
  };

  let make = (~title, ~description, ~board) => {
    id: Sihl.Core.Uuid.V4.uuidv4(),
    title,
    description,
    board,
    assignee: None,
    status: "todo",
  };
};

module Board = {
  [@decco]
  type t = {
    id: string,
    title: string,
    owner: string,
    status: string,
  };

  let make = (~title, ~owner) => {
    id: Sihl.Core.Uuid.V4.uuidv4(),
    title,
    owner,
    status: "active",
  };
};
```

Models typically consist of ReasonML modules each having one main type `t`, a smart constructor and information about decoding returns values that come from the persistence layer. In the models there should be no async code and no dependency on any infrastructure like SQL, HTTP or Logging.

### HTTP Route

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

The file doesn't compile yet because we have not implemented `Service.Board.getAllByUser((conn, user), ~userId)` yet. We do that in a second. Let's add another route for creating new boards. This will be a POST route:

```reasonml
module AddBoard = {
  [@decco]
  type body_in = {title: string};
  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/boards/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Sihl.Users.User.authenticate(conn, token);
        let%Async {title} = req.requireBody(body_in_decode);
        let%Async _ = Service.Board.create((conn, user), ~title);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};
```

Keep in mind that here we are using the function `Service.Board.create((conn, user), ~title)` which does not exist yet. We create these functions right after properly configuring the two routes we just added.

We need to add both routes to the app configuration in `App.re` so that Sihl know about them:

```reasonml
...

let routes = database => [
  Routes.GetBoardsByUser.endpoint(namespace, database),
  Routes.AddBoard.endpoint(namespace, database),
];

...
```
### Service

A service is just a collection of functions that provide functionality to the routes or to other apps.

Let's create a `Board` service with the two functions that we have used in the routes in `Service.re`:

```reasonml
module Board = {
  let getAllByUser = ((conn, user), ~userId) => {
    open! Sihl.Core.Http.Endpoint;
    if (!Sihl.Users.User.isAdmin(user) && user.id !== userId) {
      abort @@ Forbidden("Not allowed");
    };
    Repository.Board.GetAllByUser.query(conn, ~userId);
  };

  let create = ((conn, user), ~title) => {
    let board = Model.Board.make(~title, ~owner=Sihl.Users.User.id(user));
    Repository.Board.Upsert.query(conn, ~board);
  };
};
```

Note that services call models, which encapsulate business types and pure business logic and repositories, which abstract away concerns around persistence.

Authorization is done in the service while authentication is done in the HTTP route.

### Repository

Sihl makes no assumptions about the persistence layer. In this example application we have written SQL manually in repositories. A *repository* hides implementation details like what kind of database has been used.

Let's implement the repository for board in `Repository.re`.

```reasonml
module Board = {
  module Clean = {
    let stmt = "
TRUNCATE TABLE issues_boards;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = {
      connection => Sihl.Core.Db.Repo.execute(connection, stmt);
    };
  };

  module GetAllByUser = {
    let stmt = "
SELECT
  uuid_of(issues_boards.uuid) as id,
  issues_boards.title as title,
  uuid_of(users_users.uuid) as owner,
  issues_boards.status as status
FROM issues_boards
LEFT JOIN users_users
ON users_users.id  = issues_boards.owner
WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type params = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Js.Promise.t(Sihl.Core.Db.Repo.Result.t(Model.Board.t)) =
      (connection, ~userId) =>
        Sihl.Core.Db.Repo.getMany(
          ~connection,
          ~stmt,
          ~decode=Model.Board.t_decode,
          ~parameters=params_encode(userId),
          (),
        );
  };

  module Upsert = {
    let stmt = "
INSERT INTO issues_boards (
  uuid,
  title,
  owner,
  status
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  (SELECT id FROM users_users WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))),
  ?
)
ON DUPLICATE KEY UPDATE
title = VALUES(title),
owner = VALUES(owner),
status = VALUES(status)
;";

    [@decco]
    type parameters = (string, string, string, string);

    let query = (connection, ~board: Model.Board.t) =>
      Sihl.Core.Db.Repo.execute(
        ~parameters=
          parameters_encode((
            board.id,
            board.title,
            board.owner,
            board.status,
          )),
        connection,
        stmt,
      );
  };
};

```

Repositories have to implement a "clean" function that removes all data if called. This is later going to be used by the test harness in the integration tests.

The clean functions have to be configured in `App.re` so that Sihl is aware of them.

```reasonml
...

let app = () =>
  Sihl.Core.Main.App.make(
    ~name,
    ~namespace,
    ~routes,
    ~clean=[Repository.Issue.Clean.run, Repository.Board.Clean.run],
    ~migration=Migrations.MariaDb.make(~namespace),
  );

...
```

### Testing

While the type checker of ReasonML is able to catch many bugs at compile-time, we should test high-level integration of components.

Let's write an integration test where a user create a board.

Create a file `/__tests__/integration/IssueIntegrationTest.re`:

```
include Sihl.Core.Test;
Integration.setupHarness([Sihl.Users.App.app([]), App.app()]);
open Jest;
```

These three lines setup jest as the test runner and the test harness which starts the web server and removes the data between the tests.

#### Seeding

When writing integration tests we often want to test a certain functionality that requires some data in the database. The seeding mechanism allows us to fill the database with data easily prior running the test.

We want to test that a user can create a board, which requires one registered user. Luckily the `sihl-users` app provides some useful seeds which can be used like:

```reasonml
let%Async user =
  Sihl.Core.Main.Manager.seed(
    Sihl.Users.Seeds.user("foobar@example.com", "123"),
  );
```

The full test looks like:

```reasonml
let baseUrl = "http://localhost:3000";

Expect.(
  testPromise("User creates board", () => {
    let%Async user =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.user("foobar@example.com", "123"),
      );

    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=foobar@example.com&password=123",
      );
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Sihl.Users.Routes.Login.{token} =
      tokenJson
      |> Sihl.Users.Routes.Login.response_body_decode
      |> Belt.Result.getExn;
    let body = {|{"title": "Board title"}|};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/boards/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );

    let%Async boardsResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/users/" ++ Sihl.Users.User.id(user) ++ "/boards/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    let%Async boardsJson = Fetch.Response.json(boardsResponse);
    let boards =
      boardsJson
      |> Routes.GetBoardsByUser.body_out_decode
      |> Belt.Result.getExn;

    let Model.Board.{title} = boards |> Belt.List.headExn;

    title |> expect |> toBe("Board title") |> Sihl.Core.Async.async;
  })
);
```

Now we can run the test with `yarn test` given there is a running MariaDB instance. Sihl will apply migrations automatically.

### Admin UI

`sihl-users` provides first class support fort building UIs for admins to manage users. It can be easily customized by adding new pages.

We want to add a *boards* page that shows the list of boards to the admins. Create a file `AdminUi.re`:

```reasonml
module Boards = {
  module Row = {
    [@react.component]
    let make = (~board: Model.Board.t) =>
      <tr>
        <td>
          <a href={"/admin/users/users/" ++ board.owner}>
            {React.string(board.owner)}
          </a>
        </td>
        <td> {React.string(board.title)} </td>
        <td> {React.string(board.status)} </td>
      </tr>;
  };

  [@react.component]
  let make = (~boards: list(Model.Board.t)) => {
    let boardRows =
      boards
      ->Belt.List.map(board => <Row key={board.id} board />)
      ->Belt.List.toArray
      ->ReasonReact.array;

    <Sihl.Users.AdminUi.NavigationLayout title="Issues">
      <table className="table is-striped is-narrow is-hoverable is-fullwidth">
        <thead>
          <tr>
            <th> {React.string("Owner")} </th>
            <th> {React.string("Title")} </th>
            <th> {React.string("Status")} </th>
          </tr>
        </thead>
        boardRows
      </table>
    </Sihl.Users.AdminUi.NavigationLayout>;
  };
};
```

We need to configure that page so `sihl-users` can load it. This is done in the last step.

### Running the app

The app that is described in `App.re` can be started. Since our issues management app depends on `sihl-users`, we have to start them together. Create a file `Main.re`:

```reasonml
let adminUiPages = [
  Sihl.Users.AdminUi.Page.make(
    ~path="/admin/issues/boards/",
    ~label="Boards",
  ),
];

Sihl.Core.Main.Manager.startApps([
  Sihl.Users.App.app(adminUiPages),
  App.app(),
]);
```

Now you can start the app with `yarn start:server`. Huray, our first Sihl app!
