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

We create two MySQL tables:

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
