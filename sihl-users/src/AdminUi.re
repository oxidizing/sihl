module HtmlTemplate = {
  let make = (~content, ~title) => {j|
  <!DOCTYPE html>
    <html>
      <head>
        <title>$title</title>
        <link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/bulma/0.8.0/css/bulma.min.css">
        <link href="https://stackpath.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css">
      </head>
      <body>
        <div id="react-root">$content</div>
      </body>
    </html>
|j};

  let render = component => {
    let content = ReactDOMServerRe.renderToString(component);
    make(~content, ~title="Admin UI");
  };
};

module Layout = {
  [@react.component]
  let make = (~children) => {
    <div>
      <section className="hero is-small is-primary is-bold">
        <div className="hero-body">
          <div className="container">
            <h1 className="title"> {React.string("Sihl")} </h1>
            <h2 className="subtitle"> {React.string("Admin UI")} </h2>
          </div>
        </div>
      </section>
      <section className="section"> children </section>
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

module Navigation = {
  [@react.component]
  let make = (~items) => {
    <aside className="menu">
      <p className="menu-label"> {React.string("General")} </p>
      <ul className="menu-list">
        <a href="/admin/"> {React.string("Dashboard")} </a>
        <a href="/admin/users/users/"> {React.string("Users")} </a>
      </ul>
    </aside>;
  };
};

module NavigationLayout = {
  [@react.component]
  let make = (~title, ~items, ~children) => {
    <Layout>
      <div className="columns">
        <div className="column is-2 is-desktop"> <Navigation items=[] /> </div>
        <div className="column is-10">
          <div>
            <h2 className="title"> {React.string(title)} </h2>
            children
          </div>
        </div>
      </div>
    </Layout>;
  };
};

module Login = {
  [@react.component]
  let make = () =>
    <Layout>
      <div className="columns">
        <div className="column is-one-quarter" />
        <div className="column is-two-quarters">
          <form action="/admin/login/" method="get">
            <div className="field">
              <label className="label">
                {React.string("E-Mail address")}
              </label>
              <div className="control">
                <input
                  className="input"
                  name="email"
                  type_="text"
                  placeholder=""
                />
              </div>
            </div>
            <div className="field">
              <label className="label"> {React.string("Password")} </label>
              <div className="control">
                <input
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
                  className="button is-link" type_="submit" value="Login">
                  {React.string("Submit")}
                </button>
              </div>
            </div>
          </form>
        </div>
        <div className="column is-one-quarter" />
      </div>
    </Layout>;
};

module Users = {
  module Row = {
    [@react.component]
    let make = (~user: Model.User.t) =>
      <tr>
        <td> {React.string(user.givenName)} </td>
        <td> {React.string(user.familyName)} </td>
        <td> {React.string(user.email)} </td>
        <td> {React.string(string_of_bool(Model.User.isAdmin(user)))} </td>
      </tr>;
  };

  [@react.component]
  let make = (~users: list(Model.User.t)) => {
    let userRows =
      users
      ->Belt.List.map(user => <Row key={user.id} user />)
      ->Belt.List.toArray
      ->ReasonReact.array;

    <NavigationLayout title="Users" items=[]>
      <table className="table">
        <thead>
          <tr>
            <th> {React.string("Given name")} </th>
            <th> {React.string("Family name")} </th>
            <th> {React.string("Email")} </th>
            <th> {React.string("Admin?")} </th>
          </tr>
        </thead>
        userRows
      </table>
    </NavigationLayout>;
  };
};

module User = {
  [@react.component]
  let make = (~user: Model.User.t) =>
    <NavigationLayout title="User" items=[]>
      <span> {React.string("This will be the user detail")} </span>
    </NavigationLayout>;
};

module Dashboard = {
  // TODO show navigation with /users/
  [@react.component]
  let make = (~user: Model.User.t) =>
    <NavigationLayout title="Dashboard" items=[]>
      <span>
        {React.string(
           "Have a great day"
           ++ user.givenName
           ++ " "
           ++ user.familyName
           ++ "!",
         )}
      </span>
    </NavigationLayout>;
};
