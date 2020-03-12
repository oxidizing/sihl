module Page = {
  type t = {
    path: string,
    label: string,
  };
  let make = (~path, ~label) => {path, label};
};

module State = {
  let pages: Pervasives.ref(list(Page.t)) = ref([]);
};

module HtmlTemplate = {
  let make = (~content, ~title) => {j|
  <!DOCTYPE html>
    <html>
      <head>
        <title>$title</title>
        <link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/bulma/0.8.0/css/bulma.min.css">
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
  module Logout = {
    [@react.component]
    let make = () => {
      <form action="/admin/logout/" method="post">
        <button className="button is-danger is-pulled-right" type_="submit">
          {React.string("Logout")}
        </button>
      </form>;
    };
  };

  [@react.component]
  let make = (~children, ~isLoggedIn) => {
    <div>
      <section className="hero is-small is-primary is-bold">
        <div className="hero-body">
          {isLoggedIn ? <Logout /> : React.null}
          <div className="container">
            <h1 className="title"> {React.string("Sihl")} </h1>
            <h2 className="subtitle"> {React.string("Admin UI")} </h2>
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

module Navigation = {
  [@react.component]
  let make = () => {
    <aside className="menu">
      <p className="menu-label"> {React.string("General")} </p>
      <ul className="menu-list">
        {(State.pages^)
         ->Belt.List.map((item: Page.t) =>
             <a key={item.path} href={item.path}>
               {React.string(item.label)}
             </a>
           )
         ->Belt.List.toArray
         ->React.array}
      </ul>
    </aside>;
  };
};

module NavigationLayout = {
  [@react.component]
  let make = (~title, ~children) => {
    <Layout isLoggedIn=true>
      <div className="columns">
        <div className="column is-2 is-desktop"> <Navigation /> </div>
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
    <Layout isLoggedIn=false>
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
        <td>
          <a href={"/admin/users/users/" ++ user.id}>
            {React.string(user.username)}
          </a>
        </td>
        <td> {React.string(user.email)} </td>
        <td> {React.string(user.givenName)} </td>
        <td> {React.string(user.familyName)} </td>
        <td>
          {React.string(user.phone->Belt.Option.getWithDefault("-"))}
        </td>
        <td> {React.string(string_of_bool(Model.User.isAdmin(user)))} </td>
        <td> {React.string(string_of_bool(user.confirmed))} </td>
        <td> {React.string(user.status)} </td>
      </tr>;
  };

  [@react.component]
  let make = (~users: list(Model.User.t)) => {
    let userRows =
      users
      ->Belt.List.map(user => <Row key={user.id} user />)
      ->Belt.List.toArray
      ->ReasonReact.array;

    <NavigationLayout title="Users">
      <table className="table is-striped is-narrow is-hoverable is-fullwidth">
        <thead>
          <tr>
            <th> {React.string("Username")} </th>
            <th> {React.string("Email")} </th>
            <th> {React.string("Given name")} </th>
            <th> {React.string("Family name")} </th>
            <th> {React.string("Phone")} </th>
            <th> {React.string("Admin?")} </th>
            <th> {React.string("Email confirmed?")} </th>
            <th> {React.string("Status")} </th>
          </tr>
        </thead>
        userRows
      </table>
    </NavigationLayout>;
  };
};

module User = {
  module SetPasswordForm = {
    [@react.component]
    let make = (~user: Model.User.t) => {
      <form action={"/admin/users/users/" ++ user.id} method="get">
        <div className="field">
          <div className="control">
            <input
              className="input"
              name="action"
              value="set-password"
              type_="hidden"
            />
          </div>
        </div>
        <div className="field">
          <label className="label"> {React.string("New password")} </label>
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
            <button className="button is-link" type_="submit" value="Login">
              {React.string("Set")}
            </button>
          </div>
        </div>
      </form>;
    };
  };

  [@react.component]
  let make = (~user: Model.User.t, ~msg=?, ()) => {
    <NavigationLayout title={user.email}>
      <div className="columns">
        <div className="column is-one-third">
          <span> {React.string(Belt.Option.getWithDefault(msg, ""))} </span>
        </div>
      </div>
      <div className="columns">
        <div className="column is-one-third"> <SetPasswordForm user /> </div>
      </div>
      <table className="table is-striped is-narrow is-hoverable is-fullwidth">
        <thead>
          <tr>
            <th> {React.string("Username")} </th>
            <th> {React.string("Email")} </th>
            <th> {React.string("Given name")} </th>
            <th> {React.string("Family name")} </th>
            <th> {React.string("Phone")} </th>
            <th> {React.string("Admin?")} </th>
            <th> {React.string("Email confirmed?")} </th>
            <th> {React.string("Status")} </th>
          </tr>
        </thead>
        <tr>
          <td>
            <a href={"/admin/users/users/" ++ user.id}>
              {React.string(user.username)}
            </a>
          </td>
          <td> {React.string(user.email)} </td>
          <td> {React.string(user.givenName)} </td>
          <td> {React.string(user.familyName)} </td>
          <td>
            {React.string(user.phone->Belt.Option.getWithDefault("-"))}
          </td>
          <td>
            {React.string(string_of_bool(Model.User.isAdmin(user)))}
          </td>
          <td> {React.string(string_of_bool(user.confirmed))} </td>
          <td> {React.string(user.status)} </td>
        </tr>
      </table>
    </NavigationLayout>;
  };
};

module Dashboard = {
  [@react.component]
  let make = (~user: Model.User.t) =>
    <NavigationLayout title="Dashboard">
      <h4 className="title is-4">
        {React.string("Have a great day, " ++ user.givenName ++ "!")}
      </h4>
    </NavigationLayout>;
};
