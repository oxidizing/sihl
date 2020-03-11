module Async = Sihl.Core.Async;

module Layout = ClientLayout;
module Login = ClientLoginPage;

type action =
  | StartAddIssue(string, string, option(string))
  | SucceedAddIssue(string, string, string, option(string))
  | FailAddIssue(string)
  | StartCompleteIssue(string)
  | FailCompleteIssue(string, string)
  | Set(list(Model.Issue.t));

module SelectBoard = {
  let selectedBoard = () => {
    let url = ReasonReactRouter.useUrl();
    switch (url.path) {
    | ["app", "boards", boardId] => Some(boardId)
    | _ => None
    };
  };

  [@react.component]
  let make = () => {
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);
    let (boards, setBoards) = React.useState(_ => None);
    let (title, setTitle) = React.useState(_ => "");

    React.useEffect1(
      () => {
        {
          let%Async boards = ClientApi.Board.GetAll.f();
          Async.async(
            switch (boards) {
            | Belt.Result.Ok(boards) => setBoards(_ => Some(boards))
            | Belt.Result.Error(msg) => setError(_ => Some(msg))
            },
          );
        }
        ->ignore;
        None;
      },
      [||],
    );

    <div>
      <div className="field has-addons">
        <div className="control">
          <input
            onChange={event => {
              let value = ReactEvent.Form.target(event)##value;
              setTitle(_ => value);
            }}
            value=title
            className="input"
            type_="text"
            placeholder="Board title"
          />
        </div>
        <div className="control">
          <a
            className="button is-info"
            onClick={event => {
              ReactEvent.Mouse.preventDefault(event);
              ClientApi.Board.Add.f(~title)->ignore;
              ();
            }}>
            {React.string("Add board")}
          </a>
        </div>
      </div>
      <div className="field">
        <p className="control">
          <span className="select">
            <select
              value={selectedBoard()->Belt.Option.getWithDefault("select")}
              onChange={event => {
                let value = ReactEvent.Form.target(event)##value;
                let value = value === "select" ? "" : value;
                ReasonReactRouter.push("/app/boards/" ++ value);
              }}>
              <option value="select"> {React.string("Select board")} </option>
              {boards
               ->Belt.Option.getWithDefault([])
               ->Belt.List.map(board =>
                   <option key={board.id} value={board.id}>
                     {React.string(board.title)}
                   </option>
                 )
               ->Belt.List.toArray
               ->React.array}
            </select>
          </span>
        </p>
      </div>
    </div>;
  };
};

module Issue = {
  let complete = (setError, dispatch, ~issueId, ~currentStatus) => {
    {
      dispatch(StartCompleteIssue(issueId));
      let%Async result = ClientApi.Issue.Complete.f(~issueId);
      Async.async(
        switch (result) {
        | Belt.Result.Ok () => ()
        | Belt.Result.Error(msg) =>
          dispatch(FailCompleteIssue(issueId, currentStatus));
          setError(_ => Some("Failed create issue: " ++ msg));
        },
      );
    }
    ->ignore;
  };

  [@react.component]
  let make = (~issue: Model.Issue.t, ~dispatch) => {
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);
    let complete = complete(setError, dispatch);

    let statusBadge =
      issue.status === "todo"
        ? <span className="tag is-pulled-right">
            {React.string("To do")}
          </span>
        : <span className="tag is-success is-pulled-right">
            {React.string("Completed")}
          </span>;

    <div className="box">
      statusBadge
      <h4 className="is-4 title"> {React.string(issue.title)} </h4>
      {issue.description
       ->Belt.Option.map(description =>
           <span> {React.string(description)} </span>
         )
       ->Belt.Option.getWithDefault(React.null)}
      {issue.status === "todo"
         ? <button
             className="button is-small is-info is-pulled-right"
             onClick={_ =>
               complete(~issueId=issue.id, ~currentStatus=issue.status)
             }>
             {React.string("Complete")}
           </button>
         : React.null}
    </div>;
  };
};

module Issues = {
  [@react.component]
  let make = (~issues: list(Model.Issue.t), ~dispatch) => {
    <div>
      {Belt.List.length(issues) === 0
         ? <span> {React.string("No issues found")} </span>
         : issues
           ->Belt.List.map(issue => <Issue key={issue.id} issue dispatch />)
           ->Belt.List.toArray
           ->React.array}
    </div>;
  };
};

module Board = {
  [@react.component]
  let make = (~boardId, ~issues, ~dispatch) => {
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);

    React.useEffect1(
      () => {
        {
          let%Async result = ClientApi.Board.Issues.f(~boardId);
          Async.async(
            switch (result) {
            | Belt.Result.Ok(issues) => dispatch(Set(issues))
            | Belt.Result.Error(msg) => setError(_ => Some(msg))
            },
          );
        }
        ->ignore;
        None;
      },
      [|boardId|],
    );

    switch (issues) {
    | Some(issues) => <Issues issues dispatch />
    | None => <span> {React.string("Loading...")} </span>
    };
  };
};

module AddIssue = {
  let addIssue = (setError, dispatch, ~boardId, ~title, ~description) => {
    dispatch(StartAddIssue(boardId, title, description));
    let%Async result = ClientApi.Issue.Add.f(~boardId, ~title, ~description);
    Async.async(
      switch (result) {
      | Belt.Result.Ok(_) =>
        // TODO
        // dispatch(Succeed(boardId, title, description));
        ()
      | Belt.Result.Error(msg) =>
        setError(_ => Some("Failed create issue: " ++ msg));
        dispatch(FailAddIssue(boardId));
      },
    );
  };

  [@react.component]
  let make = (~boardId, ~dispatch) => {
    let (title, setTitle) = React.useState(_ => "");
    let (description, setDescription) = React.useState(_ => None);
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);
    let addIssue = addIssue(setError, dispatch);

    <div style={ReactDOMRe.Style.make(~marginBottom="2em", ())}>
      <div className="field">
        <div className="control">
          <input
            onChange={event => {
              let value = ReactEvent.Form.target(event)##value;
              setTitle(_ => value);
            }}
            value=title
            className="input"
            type_="text"
            placeholder="Issue title"
          />
        </div>
      </div>
      <div className="field">
        <div className="control">
          <textarea
            onChange={event => {
              let value = ReactEvent.Form.target(event)##value;
              setDescription(_ => value);
            }}
            value={description->Belt.Option.getWithDefault("")}
            className="textarea"
            placeholder="Description"
          />
        </div>
      </div>
      <button
        className="button is-info"
        onClick={event => {
          ReactEvent.Mouse.preventDefault(event);
          let _ = addIssue(~boardId, ~title, ~description);
          ();
        }}>
        {React.string("Add Issue")}
      </button>
    </div>;
  };
};

open Model.Issue;

let reducer = (state, action) =>
  switch (state, action) {
  | (Some(issues), StartAddIssue(boardId, title, description)) =>
    Some(
      Belt.List.concat(
        issues,
        [make(~title, ~description, ~board=boardId)],
      ),
    )
  | (None, StartAddIssue(boardId, title, description)) =>
    Some([Model.Issue.make(~title, ~description, ~board=boardId)])
  | (Some(issues), SucceedAddIssue(issueId, boardId, title, description)) =>
    let issues = Belt.List.keep(issues, issue => issue.id !== issueId);
    Some(
      Belt.List.concat(
        issues,
        [makeId(~id=issueId, ~title, ~description, ~board=boardId)],
      ),
    );
  | (None, SucceedAddIssue(issueId, boardId, title, description)) =>
    Some([makeId(~id=issueId, ~board=boardId, ~title, ~description)])
  | (None, FailAddIssue(_)) => None
  | (Some(issues), FailAddIssue(issueId)) =>
    Some(Belt.List.keep(issues, issue => issue.id !== issueId))
  | (Some(issues), StartCompleteIssue(issueId)) =>
    Some(
      Belt.List.map(issues, issue =>
        issue.id === issueId ? complete(issue) : issue
      ),
    )
  | (Some(issues), FailCompleteIssue(issueId, status)) =>
    Some(
      Belt.List.map(issues, issue =>
        issue.id === issueId ? setStatus(issue, status) : issue
      ),
    )
  | (_, Set(issues)) => Some(issues)
  | (None, StartCompleteIssue(issueId) | FailCompleteIssue(issueId, _)) =>
    Js.log(
      "How on earth were you able to call that action without issues? issueId="
      ++ issueId,
    );
    None;
  };

[@react.component]
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, None);
  let url = ReasonReactRouter.useUrl();
  <Layout>
    <div className="columns">
      <div className="column is-one-third"> <SelectBoard /> </div>
      <div className="column is-one-third">
        <h2 className="title is-2"> {React.string("Issues")} </h2>
        {switch (url.path) {
         | ["app", "boards"] =>
           <span> {React.string("Please select a board")} </span>
         | ["app", "boards", boardId] =>
           <div>
             <AddIssue dispatch boardId />
             <Board issues=state dispatch boardId />
           </div>
         | _ => <Login />
         }}
      </div>
    </div>
  </Layout>;
};
