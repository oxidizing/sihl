open Base
open Tyxml.Html

let empty = span []

module C = struct
  let title text = h1 ~a:[ a_class [ "title" ] ] [ txt text ]

  let sub_title text = h2 ~a:[ a_class [ "subtitle" ] ] [ txt text ]

  let container content = div ~a:[ a_class [ "container" ] ] content
end

let stylesheet_uri =
  "https://cdnjs.cloudflare.com/ajax/libs/bulma/0.8.0/css/bulma.min.css"

let html_page ~title:title_text content =
  html
    (head
       (title (txt title_text))
       [ link ~rel:[ `Stylesheet ] ~href:stylesheet_uri () ])
    (body content)

let logout =
  form
    ~a:[ a_action "/admin/logout/"; a_method `Post ]
    [
      button
        ~a:[ a_class [ "button"; "is-danger"; "is-pulled-right" ] ]
        [ txt "Logout" ];
    ]

let layout ~is_logged_in content =
  [
    section
      ~a:[ a_class [ "hero"; "is-small"; "is-primary"; "is-bold" ] ]
      [
        div
          ~a:[ a_class [ "hero-body" ] ]
          [
            (if is_logged_in then logout else empty);
            C.container [ C.title "Sihl"; C.sub_title "Admin UI" ];
          ];
      ];
    section ~a:[ a_class [ "section" ]; a_style "min-heigth: 40em" ] content;
    footer
      ~a:[ a_class [ "footer" ] ]
      [
        div
          ~a:[ a_class [ "content"; "has-text-centered" ] ]
          [ p [ txt "by Oxidizing Systems"; txt " | "; txt "v1.0.0 " ] ];
      ];
  ]

type page = { path : string; label : string }

let navigation pages =
  aside
    ~a:[ a_class [ "menu" ] ]
    [
      p ~a:[ a_class [ "menu-label" ] ] [ txt "General" ];
      ul
        ~a:[ a_class [ "menu-list" ] ]
        (List.map pages ~f:(fun page ->
             li [ a ~a:[ a_href page.path ] [ txt page.label ] ]));
    ]

let navigation_layout ~title ~pages content =
  layout ~is_logged_in:true
    [
      div
        ~a:[ a_class [ "columns" ] ]
        [
          div
            ~a:[ a_class [ "column"; "is-2"; "is-desktop" ] ]
            [ navigation pages ];
          div
            ~a:[ a_class [ "column"; "is-10" ] ]
            (List.cons (C.title title) content);
        ];
    ]

let render page = Caml.Format.asprintf "%a" (pp ()) page

let login =
  html_page ~title:"Login"
    (layout ~is_logged_in:false
       [
         div
           ~a:[ a_class [ "columns" ] ]
           [
             div ~a:[ a_class [ "column is-one-quarter" ] ] [];
             div
               ~a:[ a_class [ "column is-two-quarters" ] ]
               [
                 form
                   ~a:[ a_action "/admin/login/"; a_method `Post ]
                   [
                     div
                       ~a:[ a_class [ "field" ] ]
                       [
                         label
                           ~a:[ a_class [ "label" ] ]
                           [ txt "E-Mail Address" ];
                         div
                           ~a:[ a_class [ "control" ] ]
                           [
                             input
                               ~a:
                                 [
                                   a_class [ "input" ];
                                   a_name "email";
                                   a_input_type `Email;
                                 ]
                               ();
                           ];
                       ];
                     div
                       ~a:[ a_class [ "field" ] ]
                       [
                         label ~a:[ a_class [ "label" ] ] [ txt "Password" ];
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
                       ~a:[ a_class [ "field" ] ]
                       [
                         div
                           ~a:[ a_class [ "control" ] ]
                           [
                             button
                               ~a:
                                 [
                                   a_class [ "button is-link" ];
                                   a_button_type `Submit;
                                 ]
                               [ txt "Submit" ];
                           ];
                       ];
                   ];
               ];
             div ~a:[ a_class [ "column is-one-quarter" ] ] [];
           ];
       ])

let dashboard user =
  html_page ~title:"Dashboard"
    (navigation_layout ~pages:[] ~title:"Dashboard"
       [ C.sub_title ("Have a great day, " ^ Model.User.email user) ])
