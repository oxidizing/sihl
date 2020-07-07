open Base;
open Tyxml;

module User = User_model.User;

module Row = {
  let createElement = (~user, ()) => {
    let url = "/admin/users/users/" ++ User.id(user) ++ "/";
    <tr>
      <td> <a href=url> {Html.txt(User.email(user))} </a> </td>
      <td> {Html.txt(user |> User.is_admin |> Bool.to_string)} </td>
      <td> {Html.txt(user |> User.is_confirmed |> Bool.to_string)} </td>
      <td> {Html.txt(user |> User.status)} </td>
    </tr>;
  };
};

module UserListPage = {
  let createElement = (ctx, users) => {
    let elems = List.map(users, ~f=user => <Row user />);
    <Admin.Component.Page title="Users">
      <Admin.Component.NavigationLayout ctx title="Users">
        <table class_="table is-striped is-narrow is-hoverable is-fullwidth">
          <tbody>
            ...{List.cons(
              <tr>
                <th> "Email" </th>
                <th> "Admin?" </th>
                <th> "Email confirmed?" </th>
                <th> "Status" </th>
              </tr>,
              elems,
            )}
          </tbody>
        </table>
      </Admin.Component.NavigationLayout>
    </Admin.Component.Page>;
  };
};

module SetPassword = {
  let createElement = (~user, ()) => {
    let action = "/admin/users/users/" ++ User.id(user) ++ "/set-password/";
    <form action method="Post">
      <div class_="field">
        <label class_="label"> "New Password" </label>
        <div class_="control">
          <input class_="input" name="password" type_="Password" />
        </div>
      </div>
      <div class_="field is-grouped">
        <div class_="control">
          <button class_="button is-link" type_="Submit"> "Set" </button>
        </div>
      </div>
    </form>;
  };
};

module UserPage = {
  let createElement = (ctx, user) => {
    let title = "User: " ++ User.email(user);
    <Admin.Component.Page title>
      <Admin.Component.NavigationLayout ctx title>
        <div class_="columns">
          <div class_="column is-one-third"> <SetPassword user /> </div>
        </div>
        <table class_="table is-striped is-narrow is-hoverable is-fullwidth">
          <tbody>
            <tr>
              <th> "Email" </th>
              <th> "Admin?" </th>
              <th> "Email confirmed?" </th>
              <th> "Status" </th>
            </tr>
            <Row user />
          </tbody>
        </table>
      </Admin.Component.NavigationLayout>
    </Admin.Component.Page>;
  };
};

let users = Admin.create_page(~path="users", ~label="Users");
