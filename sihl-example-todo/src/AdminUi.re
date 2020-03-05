module Issues = {
  module Row = {
    [@react.component]
    let make = (~issue: Model.Issue.t) =>
      <tr>
        <td>
          <a href={"/admin/users/users/" ++ "foo"}> {React.string("foo")} </a>
        </td>
        <td> {React.string(issue.title)} </td>
        <td>
          {React.string(issue.description->Belt.Option.getWithDefault("-"))}
        </td>
        <td> {React.string(issue.board)} </td>
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

    <table className="table is-striped is-narrow is-hoverable is-fullwidth">
      <thead>
        <tr>
          <th> {React.string("Owner")} </th>
          <th> {React.string("Title")} </th>
          <th> {React.string("Description")} </th>
          <th> {React.string("Board")} </th>
          <th> {React.string("Assignee")} </th>
          <th> {React.string("Status")} </th>
        </tr>
      </thead>
      issueRows
    </table>;
  };
};
