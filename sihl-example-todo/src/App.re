let name = "Issue Management App";
let namespace = "issues";

let routes = database => [
  Routes.GetBoardsByUser.endpoint(namespace, database),
  Routes.GetIssuesByBoard.endpoint(namespace, database),
  Routes.AddBoard.endpoint(namespace, database),
  Routes.AddIssue.endpoint(namespace, database),
  Routes.AdminUi.Issues.endpoint(namespace, database),
  Routes.AdminUi.Boards.endpoint(namespace, database),
];

let app = () =>
  Sihl.Core.Main.App.make(
    ~name,
    ~namespace,
    ~routes,
    ~clean=[Repository.Issue.Clean.run, Repository.Board.Clean.run],
    ~migration=Migrations.MariaDb.make(~namespace),
  );
