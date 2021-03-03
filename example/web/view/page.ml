open Tyxml.Html

let this_title = title (txt "Welcome to Sihl!")

let common_footer =
  footer
    [ p
        [ txt "This demo was made with "
        ; a ~a:[ a_href "https://github.com/oxidizing/sihl/" ] [ txt "Sihl" ]
        ]
    ]
;;

let messages alert notice =
  match alert, notice with
  | Some alert, Some notice -> div [ p [ txt alert ]; p [ txt notice ] ]
  | None, Some notice -> div [ p [ txt notice ] ]
  | Some alert, None -> div [ p [ txt alert ] ]
  | None, None -> div []
;;

let layout content =
  html
    (head
       this_title
       [ link
           ~rel:[ `Stylesheet ]
           ~href:"https://cdn.simplecss.org/simple.min.css"
           ()
       ])
    (body
       [ header
           [ h1 [ txt "To-do list" ]
           ; txt "Edit, add and mark to-do items as done."
           ]
       ; main [ content ]
       ; common_footer
       ])
;;

let c csrf todos alert notice =
  layout
    (div
       [ messages alert notice; Todos.add csrf; br (); Todos.list csrf todos ])
;;
