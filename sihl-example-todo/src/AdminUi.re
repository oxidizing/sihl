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

module Issues = {
  module Row = {
    [@react.component]
    let make = (~issue: Model.Issue.t) =>
      <tr>
        <td>
          <a href={"/admin/issues/boards/" ++ issue.board}>
            {React.string(issue.board)}
          </a>
        </td>
        <td> {React.string(issue.title)} </td>
        <td>
          {React.string(issue.description->Belt.Option.getWithDefault("-"))}
        </td>
        <td>
          {React.string(issue.assignee->Belt.Option.getWithDefault("-"))}
        </td>
        <td> {React.string(issue.status)} </td>
      </tr>;
  };

  [@react.component]
  let make = (~issues: list(Model.Issue.t)) => {
    let issueRows =
      issues
      ->Belt.List.map(issue => <Row key={issue.id} issue />)
      ->Belt.List.toArray
      ->ReasonReact.array;

    <Sihl.Users.AdminUi.NavigationLayout title="Issues">
      <table className="table is-striped is-narrow is-hoverable is-fullwidth">
        <thead>
          <tr>
            <th> {React.string("Board")} </th>
            <th> {React.string("Title")} </th>
            <th> {React.string("Description")} </th>
            <th> {React.string("Assignee")} </th>
            <th> {React.string("Status")} </th>
          </tr>
        </thead>
        issueRows
      </table>
    </Sihl.Users.AdminUi.NavigationLayout>;
  };
};
