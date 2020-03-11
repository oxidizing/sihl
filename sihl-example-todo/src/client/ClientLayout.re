module LoginRegister = {
  [@react.component]
  let make = () => {
    <div className="is-pulled-right">
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
          <a href="https://www.oxidizing.io">
            {React.string(" Oxidizing Systems")}
          </a>
          {React.string(" | ")}
          {React.string("v0.0.1")}
        </p>
      </div>
    </footer>
  </div>;
};
