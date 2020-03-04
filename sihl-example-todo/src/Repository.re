module Async = Sihl.Core.Async;

module Issue = {
  module Clean = {
    let stmt = "
TRUNCATE TABLE issues_issues;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = {
      connection => Sihl.Core.Db.Repo.execute(connection, stmt);
    };
  };

  module GetAll = {
    let stmt = "
SELECT
  uuid_of(issues_issues.uuid) as id,
  issues_issues.title as title,
  issues_issues.description as description,
  uuid_of(issues_boards.uuid) as board,
  uuid_of(users_users.uuid) as assignee,
  issues_issues.status as status
FROM issues_issues
LEFT JOIN users_users
ON users_users.id = issues_issues.assignee
LEFT JOIN issues_boards
ON issues_boards.id = issues_issues.board;
";

    let query:
      Sihl.Core.Db.Connection.t =>
      Js.Promise.t(Sihl.Core.Db.Repo.Result.t(Model.Issue.t)) =
      connection =>
        Sihl.Core.Db.Repo.getMany(
          ~connection,
          ~stmt,
          ~decode=Model.Issue.t_decode,
          (),
        );
  };

  module GetAllByUser = {
    let stmt = "
SELECT
  uuid_of(issues_issues.uuid) as id,
  issues_issues.title as title,
  issues_issues.description as description,
  uuid_of(issues_boards.uuid) as board,
  uuid_of(users_users.uuid) as assignee,
  issues_issues.status as status
FROM issues_issues
LEFT JOIN users.users
ON users_users.id = issues_issues.assignee
LEFT JOIN issues.boards
ON issues_boards.id = issues_issues.board
WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type params = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Js.Promise.t(Sihl.Core.Db.Repo.Result.t(Model.Issue.t)) =
      (connection, ~userId) =>
        Sihl.Core.Db.Repo.getMany(
          ~connection,
          ~stmt,
          ~decode=Model.Issue.t_decode,
          ~parameters=params_encode(userId),
          (),
        );
  };

  module Get = {
    let stmt = "
SELECT
  uuid_of(issues_issues.uuid) as id,
  issues_issues.title as title,
  issues_issues.description as description,
  uuid_of(users_boards.uuid) as board,
  uuid_of(users_users.uuid) as assignee,
  issues_issues.status as status
FROM issues_issues
LEFT JOIN users.users
ON users.users.id = issues_issues.assignee
LEFT JOIN issues.boards
ON issues.boards.id = issues_issues.board
WHERE issues_issues.uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type parameters = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~issueId: string) =>
      Js.Promise.t(Belt.Result.t(Model.Issue.t, string)) = {
      (connection, ~issueId) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(issueId),
          ~decode=Model.Issue.t_decode,
          (),
        );
    };
  };

  module Upsert = {
    let stmt = "
INSERT INTO issues_issues (
  uuid,
  title,
  description,
  board,
  assignee,
  status
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  ?,
  ?,
  (SELECT id FROM issues_boards WHERE issues_boards.uuid = UNHEX(REPLACE(?, '-', ''))),
  (SELECT id FROM users_users WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))),
  ?
) ON DUPLICATE KEY UPDATE
title = VALUES(title),
description = VALUES(description),
board = VALUES(board),
assignee = VALUES(assignee),
status = VALUES(status)
;";

    [@decco]
    type parameters = (
      string,
      string,
      option(string),
      string,
      option(string),
      string,
    );

    let query = (connection, ~issue: Model.Issue.t) =>
      Sihl.Core.Db.Repo.execute(
        ~parameters=
          parameters_encode((
            issue.id,
            issue.title,
            issue.description,
            issue.board,
            issue.assignee,
            issue.status,
          )),
        connection,
        stmt,
      );
  };
};

module Board = {
  module Clean = {
    let stmt = "
TRUNCATE TABLE issues_boards;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) = {
      connection => Sihl.Core.Db.Repo.execute(connection, stmt);
    };
  };

  module Get = {
    let stmt = "
SELECT
  uuid_of(issues_boards.uuid) as id,
  issues_boards.title as title,
  uuid_of(users_users.uuid) as owner,
  issues_boards.status as status
FROM issues_boards
LEFT JOIN users_users
ON users_users.id  = issues_boards.owner
WHERE issues_boards.uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type params = string;

    let query:
      (Sihl.Core.Db.Connection.t, ~boardId: string) =>
      Js.Promise.t(Belt.Result.t(Model.Board.t, string)) =
      (connection, ~boardId) =>
        Sihl.Core.Db.Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=params_encode(boardId),
          ~decode=Model.Board.t_decode,
          (),
        );
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
