open Base;
open Tyxml;

module Row = {
  let createElement = (~user, ()) => {
    let url = "/admin/users/users/" ++ Model.User.id(user) ++ "/";
    <tr>
      <td> <a href=url> {Html.txt(Model.User.email(user))} </a> </td>
      <td> {Html.txt(user |> Model.User.is_admin |> Bool.to_string)} </td>
      <td> {Html.txt(user |> Model.User.is_confirmed |> Bool.to_string)} </td>
      <td> {Html.txt(user |> Model.User.status)} </td>
    </tr>;
  };
};

module UserListPage = {
  let createElement = (~pages, ~message, ~users, ()) => {
    let elems = List.map(users, ~f=user => <Row user />);
    <Admin_component.Page title="Users">
      <Admin_component.NavigationLayout pages message title="Users">
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
      </Admin_component.NavigationLayout>
    </Admin_component.Page>;
  };
};

module SetPassword = {
  let createElement = (~user, ()) => {
    let action =
      "/admin/users/users/" ++ Model.User.id(user) ++ "/set-password/";
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
  let createElement = (~pages, ~message, ~user) => {
    let title = "User: " ++ Model.User.email(user);
    <Admin_component.Page title>
      <Admin_component.NavigationLayout pages message title>
        <div class_="columns">
          <div class_="column is-one-third"> <SetPassword user /> </div>
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
        </div>
      </Admin_component.NavigationLayout>
    </Admin_component.Page>;
  };
};
