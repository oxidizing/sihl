module Login = {
  [@react.component]
  let make = () =>
    <div>
      <form action="/admin/login/" method="get">
        <div>
          <label> {React.string("Enter your email: ")} </label>
          <input type_="email" name="email" id="email" required=true />
        </div>
        <div>
          <label> {React.string("Enter your password: ")} </label>
          <input
            type_="password"
            name="password"
            id="password"
            required=true
          />
        </div>
        <div> <input type_="submit" value="Login" /> </div>
      </form>
    </div>;
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
      ->Belt.List.map(user => <Row user />)
      ->Belt.List.toArray
      ->ReasonReact.array;
    <div>
      <table>
        <tr>
          <th> {React.string("Given name")} </th>
          <th> {React.string("Family name")} </th>
          <th> {React.string("Email")} </th>
          <th> {React.string("Admin?")} </th>
        </tr>
        userRows
      </table>
    </div>;
  };
};

module User = {
  [@react.component]
  let make = (~user: Model.User.t) =>
    <div> <span> {React.string("hello there " ++ "foo")} </span> </div>;
};

module Dashboard = {
  // TODO show navigation with /users/
  [@react.component]
  let make = (~user: Model.User.t) =>
    <div>
      <span> {React.string("hello there " ++ user.email)} </span>
      <a href="/admin/users/users/"> {React.string("All users")} </a>
    </div>;
};
