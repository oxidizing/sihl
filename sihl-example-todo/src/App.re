let name = "Issue Management App";
let namespace = "issues";

let routes = database => [];

let app =
  Sihl.Core.Main.App.make(
    ~name,
    ~namespace,
    ~routes,
    ~clean=[Repository.Issue.Clean.run],
    ~migration=Migrations.MariaDb.make(~namespace),
  );
