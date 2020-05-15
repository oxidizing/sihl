open Base
open Tyxml.Html

let empty = span []

module Page = struct
  type t = { path : string; label : string }

  let path page = page.path

  let label page = page.label

  let create ~path ~label = { path; label }
end

module Store = struct
  let pages : Page.t list ref = ref []

  let register page =
    Logs.info (fun m -> m "registering admin ui page: %s" (Page.label page));
    pages :=
      !pages |> List.cons page
      |> List.sort ~compare:(fun p1 p2 ->
             String.compare (Page.path p1) (Page.path p2));
    ()

  let get_all () = !pages
end

let register_page = Store.register

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

let flash_section ~flash =
  match flash with
  | Some (Sihl.Flash.Error msg) ->
      section
        ~a:[ a_class [ "hero is-small is-danger" ]; a_style "margin-top: 2em;" ]
        [ div ~a:[ a_class [ "hero-body" ] ] [ txt msg ] ]
  | Some (Sihl.Flash.Warning msg) ->
      section
        ~a:
          [
            a_class [ "hero"; "is-small"; "is-warning" ];
            a_style "margin-top: 2em;";
          ]
        [ div ~a:[ a_class [ "hero-body" ] ] [ txt msg ] ]
  | Some (Sihl.Flash.Success msg) ->
      section
        ~a:
          [
            a_class [ "hero"; "is-small"; "is-success" ];
            a_style "margin-top: 2em;";
          ]
        [ div ~a:[ a_class [ "hero-body" ] ] [ txt msg ] ]
  | None -> div []

let layout ~flash ~is_logged_in content =
  [
    section
      ~a:[ a_class [ "hero"; "is-small"; "is-primary"; "is-bold" ] ]
      [
        div
          ~a:[ a_class [ "hero-body" ] ]
          [
            (if is_logged_in then logout else empty);
            div
              ~a:[ a_class [ "container is-pulled-left" ] ]
              [
                h1 ~a:[ a_class [ "title" ] ] [ txt "Sihl" ];
                h2 ~a:[ a_class [ "subtitle" ] ] [ txt "Admin UI" ];
              ];
          ];
      ];
    flash_section ~flash;
    section ~a:[ a_class [ "section" ]; a_style "min-heigth: 40em" ] content;
    footer
      ~a:[ a_class [ "footer" ] ]
      [
        div
          ~a:[ a_class [ "content"; "has-text-centered" ] ]
          [ p [ txt "by Oxidizing Systems"; txt " | "; txt "v1.0.0 " ] ];
      ];
  ]

let navigation () =
  let pages = Store.get_all () in
  aside
    ~a:[ a_class [ "menu" ] ]
    [
      p ~a:[ a_class [ "menu-label" ] ] [ txt "General" ];
      ul
        ~a:[ a_class [ "menu-list" ] ]
        (List.map pages ~f:(fun page ->
             li [ a ~a:[ a_href (Page.path page) ] [ txt (Page.label page) ] ]));
    ]

let navigation_layout ~flash ~title content =
  layout ~flash ~is_logged_in:true
    [
      div
        ~a:[ a_class [ "columns" ] ]
        [
          div
            ~a:[ a_class [ "column"; "is-2"; "is-desktop" ] ]
            [ navigation () ];
          div
            ~a:[ a_class [ "column"; "is-10" ] ]
            (List.cons (h1 ~a:[ a_class [ "title" ] ] [ txt title ]) content);
        ];
    ]

let render page = Caml.Format.asprintf "%a" (pp ()) page

let login_page ~flash =
  html_page ~title:"Login"
    (layout ~flash ~is_logged_in:false
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

let dashboard_page ~flash user =
  html_page ~title:"Dashboard"
    (navigation_layout ~flash ~title:"Dashboard"
       [
         h1
           ~a:[ a_class [ "subtitle" ] ]
           [ txt @@ "Have a great day, " ^ Model.User.email user ];
       ])
