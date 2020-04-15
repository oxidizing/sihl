open Core
open Tyxml

(** A <head> component shared by all pages *)
let default_head =
  let open Html in
  head
    (title (txt "OCaml Webapp Tutorial"))
    [ meta ~a:[a_charset "UTF-8"] ()
    ; link ~rel:[`Stylesheet] ~href:"/static/style.css" () ]

(** The basic page layout, emitted as an [`Html string] which Opium can use as a
    response *)
let basic_page content =
  let raw_html =
    let open Html in
    html default_head (body content)
    |> Format.asprintf "%a" (Html.pp ~indent:true ())
  in
  `Html raw_html

(** Short hand for link formatting *)
let hyper_link name addr = Html.(a ~a:[a_href addr] [txt name])

let welcome_page =
  basic_page
    Html.[ h1 [ txt "OCaml Webapp Tutorial" ]
         ; h2 [ txt "Hello" ]
         ; ul (List.map ~f:(fun x -> li [x])
                 [ hyper_link "hiya" "/hello"
                 ; hyper_link "中文" "/hello/中文"
                 ; hyper_link "Deutsch" "/hello/Deutsch"
                 ; hyper_link "English" "/hello/English"
                 ])
         ; h2 [ txt "Excerpts" ]
         ; ul (List.map ~f:(fun x -> li [x])
                 [ hyper_link "Add Excerpt" "/excerpts/add"
                 ; hyper_link "Excerpts" "/excerpts"
                 ])
         ]

let hello_page lang =
  let greeting = match lang with
    | "中文"    -> "你好，世界!"
    | "Deutsch" -> "Hallo, Welt!"
    | "English" -> "Hello, World!"
    | _         -> "Language not supported :(\nYou can add a language via PR to https://gitlab.com/shonfeder/ocaml_webapp"
  in
  basic_page Html.[p [txt greeting]]

let add_excerpt_page =
  let txt_input name =
    Html.[ label ~a:[a_label_for name] [txt (String.capitalize name)]
         ; input ~a:[a_input_type `Text; a_name name] () ]
  in
  let excerpt_input =
    let name = "excerpt" in
    Html.[ label ~a:[a_label_for name] [txt (String.capitalize name)]
         ; textarea ~a:[a_name name] (txt "") ]
  in
  let submit =
    Html.[input ~a:[ a_input_type `Submit; a_value "Submit"] () ]
  in
  basic_page
    Html.[ form ~a:[a_method `Post; a_action "/excerpts/add"]
             (List.map ~f:p
                [ txt_input "author"
                ; excerpt_input
                ; txt_input "source"
                ; txt_input "page"
                ; submit
                ])]

let excerpt_elt (e : Excerpt.t) =
  let page = match e.page with
    | None -> ""
    | Some p -> Printf.sprintf ", %s" p
  in
  Html.( blockquote
           ~a:[a_class ["excerpt"]]
           [ p [txt e.excerpt]
           ; p [txt (Printf.sprintf "-- %s (%s%s)" e.author e.source page)]])

let excerpt_added_page (e : Excerpt.t) =
  basic_page
    Html.[ p [txt ("Added the following excerpt: ")]
         ; excerpt_elt e ]

let excerpts_listing_page (es : Excerpt.t list) =
  basic_page
    Html.(h1 [txt "Excerpts"] ::
          List.map ~f:excerpt_elt es)

let author_excerpts_link author =
  hyper_link author (Printf.sprintf "/excerpts/author/%s" author)

let author_excerpts_page authors =
  basic_page
    Html.[ h1 [txt "Authors with excerpts"]
         ; ul (List.map ~f:(fun a -> li [author_excerpts_link a]) authors)
         ]

let error_page err =
  basic_page
    Html.[ p [txt (Printf.sprintf "Oh no! Something went wrong: %s" err)] ]
