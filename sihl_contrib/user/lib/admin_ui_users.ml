open Base
open Tyxml.Html
open Admin_ui

let user_row user =
  tr
    [
      td
        [
          a
            ~a:[ a_href ("/admin/users/users/" ^ Model.User.id user ^ "/") ]
            [ txt (Model.User.email user) ];
        ];
      td [ txt (user |> Model.User.is_admin |> Bool.to_string) ];
      td [ txt (user |> Model.User.is_confirmed |> Bool.to_string) ];
      td [ txt (Model.User.status user) ];
    ]

let users_page ~flash users =
  html_page ~title:"Users"
    (navigation_layout ~flash ~title:"Users"
       [
         table
           ~a:
             [
               a_class
                 [
                   "table";
                   "is-striped";
                   "is-narrow";
                   "is-hoverable";
                   "is-fullwidth";
                 ];
             ]
           (List.cons
              (tr
                 [
                   th [ txt "Email" ];
                   th [ txt "Admin?" ];
                   th [ txt "Email confirmed?" ];
                   th [ txt "Status" ];
                 ])
              (List.map users ~f:user_row));
       ])

let set_password user =
  [
    form
      ~a:
        [
          a_action
            ("/admin/users/users/" ^ Model.User.id user ^ "/set-password/");
          a_method `Post;
        ]
      [
        div
          ~a:[ a_class [ "field" ] ]
          [
            label ~a:[ a_class [ "label" ] ] [ txt "New Password" ];
            div
              ~a:[ a_class [ "control" ] ]
              [
                input
                  ~a:
                    [
                      a_class [ "input" ];
                      a_name "password";
                      a_input_type `Password;
                    ]
                  ();
              ];
          ];
        div
          ~a:[ a_class [ "field is-grouped" ] ]
          [
            div
              ~a:[ a_class [ "control" ] ]
              [
                button
                  ~a:[ a_class [ "button is-link" ]; a_button_type `Submit ]
                  [ txt "Set" ];
              ];
          ];
      ];
  ]

let user_page ~flash user =
  html_page ~title:"User"
    (navigation_layout ~flash
       ~title:("User: " ^ Model.User.email user)
       [
         div
           ~a:[ a_class [ "columns" ] ]
           [
             div ~a:[ a_class [ "column"; "is-one-third" ] ] (set_password user);
           ];
         table
           ~a:
             [
               a_class
                 [
                   "table";
                   "is-striped";
                   "is-narrow";
                   "is-hoverable";
                   "is-fullwidth";
                 ];
             ]
           [
             tr
               [
                 th [ txt "Email" ];
                 th [ txt "Admin?" ];
                 th [ txt "Email confirmed?" ];
                 th [ txt "Status" ];
               ];
             user_row user;
           ];
       ])
