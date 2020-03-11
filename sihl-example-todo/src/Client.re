module Async = Sihl.Core.Async;

module Layout = {
  module LoginRegister = {
    [@react.component]
    let make = () => {
      <div>
        <div className="field is-grouped">
          <div className="control">
            <button
              className="button"
              onClick={event => {
                ReactEvent.Mouse.preventDefault(event);
                ReasonReactRouter.push("/app/login");
              }}>
              {React.string("Login")}
            </button>
          </div>
          <div className="control">
            <button
              className="button"
              onClick={event => {
                ReactEvent.Mouse.preventDefault(event);
                ReasonReactRouter.push("/app/register");
              }}>
              {React.string("Register")}
            </button>
          </div>
        </div>
      </div>;
    };
  };

  module Logout = {
    [@react.component]
    let make = () => {
      <button
        className="button is-danger is-pulled-right"
        onClick={event => {
          let _ = ReactEvent.Mouse.preventDefault(event);
          ReasonReactRouter.push("/app/login");
          ClientUtils.Token.delete();
          ClientUtils.User.currentUser := None;
        }}>
        {React.string("Logout")}
      </button>;
    };
  };

  [@react.component]
  let make = (~children) => {
    <div>
      <section className="hero is-small is-primary is-bold">
        <div className="hero-body">
          <div className="columns">
            <div className="column is-three-quarter">
              <div className="container">
                <h1 className="title">
                  {React.string("Issue Management App")}
                </h1>
                <h2 className="subtitle"> {React.string("Sihl Demo")} </h2>
              </div>
            </div>
            <div className="column is-one-quarter">
              {ClientUtils.User.isLoggedIn() ? <Logout /> : <LoginRegister />}
            </div>
          </div>
        </div>
      </section>
      <section
        className="section"
        style={ReactDOMRe.Style.make(~minHeight="40em", ())}>
        children
      </section>
      <footer className="footer">
        <div className="content has-text-centered">
          <p>
            {React.string({js|\u00a9|js})}
            {React.string(" Oxidizing Systems")}
            {React.string(" | ")}
            {React.string("v0.0.1")}
          </p>
        </div>
      </footer>
    </div>;
  };
};

module Register = {
  let register =
      (
        setError,
        setMsg,
        ~username,
        ~givenName,
        ~familyName,
        ~email,
        ~password,
      ) => {
    let username = username->Belt.Option.getWithDefault("test-user");
    let givenName = givenName->Belt.Option.getWithDefault("Test");
    let familyName = familyName->Belt.Option.getWithDefault("User");
    let email = email->Belt.Option.getWithDefault("test-user@example.com");
    let password = password->Belt.Option.getWithDefault("123");
    let body = {j|
       {
         "email": "$(email)",
         "username": "$(username)",
         "password": "$(password)",
         "givenName": "$(givenName)",
         "familyName": "$(familyName)"
       }
       |j};

    Fetch.fetchWithInit(
      ClientConfig.baseUrl() ++ "/users/register/",
      Fetch.RequestInit.make(
        ~method_=Post,
        ~body=Fetch.BodyInit.make(body),
        (),
      ),
    )
    ->ClientUtils.handleResponse(
        _ => {
          ReasonReactRouter.push("/app/login");
          Async.async(
            setMsg(_ => Some("Registration successful, you can now log in!")),
          );
        },
        msg =>
          Async.async(setError(_ => Some("Failed to register: " ++ msg))),
      );
  };

  [@react.component]
  let make = () => {
    let (username, setUsername) = React.useState(() => None);
    let (givenName, setGivenName) = React.useState(() => None);
    let (familyName, setFamilyName) = React.useState(() => None);
    let (email, setEmail) = React.useState(() => None);
    let (password, setPassword) = React.useState(() => None);
    let canSubmit =
      switch (username, givenName, familyName, email, password) {
      | (Some(_), Some(_), Some(_), Some(_), Some(_)) => true
      | _ => false
      };
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);
    let (_, setMsg) =
      React.useContext(ClientContextProvider.Message.context);

    <Layout>
      <div className="columns">
        <div className="column is-one-quarter" />
        <div className="column is-two-quarters">
          <h2 className="title is-2"> {React.string("Register")} </h2>
          <div className="field">
            <label className="label"> {React.string("Username")} </label>
            <div className="control">
              <input
                value={username->Belt.Option.getWithDefault("")}
                onChange={event => {
                  let username = ClientUtils.wrapFormValue(event);
                  setUsername(_ => username);
                }}
                className="input"
                type_="text"
                required=true
                placeholder=""
              />
            </div>
          </div>
          <div className="field">
            <label className="label"> {React.string("Given name")} </label>
            <div className="control">
              <input
                onChange={event => {
                  let givenName = ClientUtils.wrapFormValue(event);
                  setGivenName(_ => givenName);
                }}
                value={givenName->Belt.Option.getWithDefault("")}
                className="input"
                name="givenName"
                type_="text"
                placeholder=""
              />
            </div>
          </div>
          <div className="field">
            <label className="label"> {React.string("Family name")} </label>
            <div className="control">
              <input
                onChange={event => {
                  let familyName = ClientUtils.wrapFormValue(event);
                  setFamilyName(_ => familyName);
                }}
                value={familyName->Belt.Option.getWithDefault("")}
                className="input"
                name="familyName"
                type_="text"
                placeholder=""
              />
            </div>
          </div>
          <div className="field">
            <label className="label"> {React.string("Email address")} </label>
            <div className="control">
              <input
                onChange={event => {
                  let email = ClientUtils.wrapFormValue(event);
                  setEmail(_ => email);
                }}
                value={email->Belt.Option.getWithDefault("")}
                className="input"
                name="email"
                type_="email"
                placeholder=""
              />
            </div>
          </div>
          <div className="field">
            <label className="label"> {React.string("Password")} </label>
            <div className="control">
              <input
                onChange={event => {
                  let password = ClientUtils.wrapFormValue(event);
                  setPassword(_ => password);
                }}
                value={password->Belt.Option.getWithDefault("")}
                className="input"
                name="password"
                type_="password"
                placeholder=""
              />
            </div>
          </div>
          <div className="field is-grouped">
            <div className="control">
              <button
                className="button is-link"
                disabled={!canSubmit}
                onClick={_ => {
                  let _ =
                    register(
                      setError,
                      setMsg,
                      ~username,
                      ~givenName,
                      ~familyName,
                      ~email,
                      ~password,
                    );
                  ();
                }}>
                {React.string("Register")}
              </button>
            </div>
          </div>
        </div>
        <div className="column is-one-quarter" />
      </div>
    </Layout>;
  };
};

module Login = {
  [@decco]
  type t = {token: string};

  let login = (setError, ~email, ~password) => {
    let email = email->Belt.Option.getWithDefault("");
    let password = password->Belt.Option.getWithDefault("");
    Fetch.fetch(
      ClientConfig.baseUrl()
      ++ "/users/login?email="
      ++ email
      ++ "&password="
      ++ password,
    )
    ->ClientUtils.handleResponse(
        response => {
          switch (t_decode(response)) {
          | Belt.Result.Ok({token}) =>
            ClientUtils.Token.set(token);
            Async.async(ReasonReactRouter.push("/app/boards/"));
          | Belt.Result.Error(error) =>
            Async.async(
              setError(_ => Some(Sihl.Core.Error.Decco.stringify(error))),
            )
          }
        },
        msg => Async.async(setError(_ => Some("Failed to login: " ++ msg))),
      );
  };

  [@react.component]
  let make = () => {
    let (email, setEmail) = React.useState(() => None);
    let (password, setPassword) = React.useState(() => None);
    let canSubmit =
      switch (email, password) {
      | (Some(_), Some(_)) => true
      | _ => false
      };
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);

    <Layout>
      <div className="columns">
        <div className="column is-one-quarter" />
        <div className="column is-two-quarters">
          <h2 className="title is-2"> {React.string("Login")} </h2>
          <div className="field">
            <label className="label"> {React.string("Email address")} </label>
            <div className="control has-icons-left">
              <input
                onChange={event => {
                  let email = ClientUtils.wrapFormValue(event);
                  setEmail(_ => email);
                }}
                value={email->Belt.Option.getWithDefault("")}
                className="input"
                name="email"
                type_="email"
                placeholder=""
              />
              <span className="icon is-small is-left">
                <i className="fas fa-envelope" />
              </span>
            </div>
          </div>
          <div className="field">
            <label className="label"> {React.string("Password")} </label>
            <div className="control has-icons-left">
              <input
                onChange={event => {
                  let password = ClientUtils.wrapFormValue(event);
                  setPassword(_ => password);
                }}
                value={password->Belt.Option.getWithDefault("")}
                className="input"
                name="password"
                type_="password"
                placeholder=""
              />
              <span className="icon is-small is-left">
                <i className="fas fa-lock" />
              </span>
            </div>
          </div>
          <div className="field is-grouped">
            <div className="control">
              <button
                className="button is-link"
                disabled={!canSubmit}
                onClick={_ => {
                  let _ = login(setError, ~email, ~password);
                  ();
                }}>
                {React.string("Login")}
              </button>
            </div>
          </div>
        </div>
        <div className="column is-one-quarter" />
      </div>
    </Layout>;
  };
};

module SelectBoard = {
  let selectedBoard = () => {
    let url = ReasonReactRouter.useUrl();
    switch (url.path) {
    | ["app", "boards", boardId] => Some(boardId)
    | _ => None
    };
  };

  [@decco]
  type t = list(Model.Board.t);

  [@react.component]
  let make = () => {
    let (boards, setBoards) = React.useState(_ => None);
    let (title, setTitle) = React.useState(_ => "");

    React.useEffect1(
      () => {
        {
          let%Async user = ClientUtils.User.get();
          let%Async response =
            Fetch.fetchWithInit(
              ClientConfig.baseUrl()
              ++ "/issues/users/"
              ++ user.id
              ++ "/boards/",
              Fetch.RequestInit.make(
                ~method_=Get,
                ~headers=
                  Fetch.HeadersInit.make({
                    "authorization": "Bearer " ++ ClientUtils.Token.get(),
                  }),
                (),
              ),
            );
          let%Async json = Fetch.Response.json(response);
          Async.async(
            switch (t_decode(json)) {
            | Belt.Result.Ok(boards) => setBoards(_ => Some(boards))
            | Belt.Result.Error(msg) =>
              Js.log(Sihl.Core.Error.Decco.stringify(msg))
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
              let body = {j|{"title": "$(title)"}|j};
              Fetch.fetchWithInit(
                ClientConfig.baseUrl() ++ "/issues/boards/",
                Fetch.RequestInit.make(
                  ~method_=Post,
                  ~body=Fetch.BodyInit.make(body),
                  ~headers=
                    Fetch.HeadersInit.make({
                      "authorization": "Bearer " ++ ClientUtils.Token.get(),
                    }),
                  (),
                ),
              )
              ->ignore;
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

type action =
  | StartAddIssue(string, string, option(string))
  | SucceedAddIssue(string, string, string, option(string))
  | FailAddIssue(string)
  | StartCompleteIssue(string)
  | FailCompleteIssue(string, string)
  | Set(list(Model.Issue.t));

module Issue = {
  [@react.component]
  let make = (~issue: Model.Issue.t) =>
    <div className="box"> <span> {React.string(issue.title)} </span> </div>;
};

module Issues = {
  [@react.component]
  let make = (~issues: list(Model.Issue.t)) => {
    <div>
      {Belt.List.length(issues) === 0
         ? <span> {React.string("No issues found")} </span>
         : issues
           ->Belt.List.map(issue => <Issue key={issue.id} issue />)
           ->Belt.List.toArray
           ->React.array}
    </div>;
  };
};

module Board = {
  [@decco]
  type t = list(Model.Issue.t);

  [@react.component]
  let make = (~boardId, ~issues, ~dispatch) => {
    React.useEffect1(
      () => {
        {
          let%Async response =
            Fetch.fetchWithInit(
              ClientConfig.baseUrl()
              ++ "/issues/boards/"
              ++ boardId
              ++ "/issues/",
              Fetch.RequestInit.make(
                ~method_=Get,
                ~headers=
                  Fetch.HeadersInit.make({
                    "authorization": "Bearer " ++ ClientUtils.Token.get(),
                  }),
                (),
              ),
            );
          let%Async json = Fetch.Response.json(response);
          Async.async(
            switch (t_decode(json)) {
            | Belt.Result.Ok(issues) => dispatch(Set(issues))
            | Belt.Result.Error(msg) =>
              Js.log(Sihl.Core.Error.Decco.stringify(msg))
            },
          );
        }
        ->ignore;
        None;
      },
      [||],
    );

    switch (issues) {
    | Some(issues) => <Issues issues />
    | None => <span> {React.string("Loading...")} </span>
    };
  };
};

module AddIssue = {
  [@react.component]
  let make = (~boardId, ~dispatch) => {
    let (title, setTitle) = React.useState(_ => "");
    let (description, setDescription) = React.useState(_ => None);
    let (_, setError) =
      React.useContext(ClientContextProvider.Error.context);

    let addIssue = (~boardId, ~title, ~description) => {
      dispatch(StartAddIssue(boardId, title, description));
      let body = {j|
       {
         "board": "$(boardId)",
         "title": "$(title)",
         "description": "$(description)"
       }
       |j};
      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/issues/issues/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({
              "authorization": ClientUtils.Token.get(),
            }),
          (),
        ),
      )
      ->ClientUtils.handleResponse(
          _ => Async.async(),
          msg =>
            Async.async(setError(_ => Some("Failed create issue: " ++ msg))),
        );
    };

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

module Boards = {
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
};

module Route = {
  [@react.component]
  let make = () => {
    let url = ReasonReactRouter.useUrl();
    switch (url.path) {
    | ["app", "login"] => <Login />
    | ["app", "register"] => <Register />
    | ["app", "boards", ..._] => <Boards />
    | _ => <Login />
    };
  };
};

module Main = {
  [@react.component]
  let make = (~children) => {
    let (error, setError) = React.useState(_ => None);
    let (message, setMessage) = React.useState(_ => None);

    <ClientContextProvider.Message value=(message, setMessage)>
      <ClientContextProvider.Error value=(error, setError)>
        <ClientNotification.Error />
        <ClientNotification.Message />
        children
      </ClientContextProvider.Error>
    </ClientContextProvider.Message>;
  };
};

ReactDOMRe.renderToElementWithId(<Main> <Route /> </Main>, "app");
