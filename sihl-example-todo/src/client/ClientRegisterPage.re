module Async = Sihl.Core.Async;
module Layout = ClientLayout;

let register =
    (setError, setMsg, ~username, ~givenName, ~familyName, ~email, ~password) => {
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
      msg => Async.async(setError(_ => Some("Failed to register: " ++ msg))),
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
  let (_, setError) = React.useContext(ClientContextProvider.Error.context);
  let (_, setMsg) = React.useContext(ClientContextProvider.Message.context);

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
