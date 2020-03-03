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
LEFT JOIN issues_issues
ON issues_issues.assignee = users_users.id
LEFT JOIN issues_issues
ON issues_issues.board = issues_boards.id;
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
LEFT JOIN issues_issues
ON issues_issues.assignee = users_users.id
LEFT JOIN issues_issues
ON issues_issues.board = issues_boards.id
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
      string,
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
