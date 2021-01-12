(* The templates and components. *)

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

let home_page_doc content =
  html
    (head
       this_title
       [ link ~rel:[ `Stylesheet ] ~href:"https://cdn.simplecss.org/simple.min.css" () ])
    (body
       [ header [ h1 [ txt "To-do list" ]; txt "Edit, add and mark to-do items as done." ]
       ; main [ content ]
       ; common_footer
       ])
;;

let add_form csrf =
  form
    ~a:[ a_method `Post; a_action (uri_of_string "/add") ]
    [ p
        [ label [ txt "Description" ]
        ; br ()
        ; input
            ~a:[ a_input_type `Text; a_name "description"; a_placeholder "Do laundry" ]
            ()
        ]
    ; p [ input ~a:[ a_input_type `Hidden; a_name "csrf"; a_value csrf ] () ]
    ; button [ span [ txt "Add" ] ]
    ]
;;

let todo_list csrf todos =
  let open Todo.Model in
  div
    [ table
        ~thead:(thead [ tr [ th [ txt "Description" ] ] ])
        (Caml.List.map
           (fun { id; description; status; _ } ->
             tr
               [ td
                   [ span [ txt description ]
                   ; (match status with
                     | Done -> div [ txt "Done" ]
                     | Active ->
                       div
                         [ form
                             ~a:[ a_method `Post; a_action (uri_of_string "/do") ]
                             [ input
                                 ~a:[ a_input_type `Hidden; a_name "csrf"; a_value csrf ]
                                 ()
                             ; input
                                 ~a:[ a_input_type `Hidden; a_name "id"; a_value id ]
                                 ()
                             ; button [ span [ txt "Do" ] ]
                             ]
                         ])
                   ]
               ])
           todos)
    ]
;;

let messages alert notice =
  match alert, notice with
  | Some alert, Some notice -> div [ p [ txt alert ]; p [ txt notice ] ]
  | None, Some notice -> div [ p [ txt notice ] ]
  | Some alert, None -> div [ p [ txt alert ] ]
  | None, None -> div []
;;

let page csrf todos alert notice =
  home_page_doc
    (div [ messages alert notice; add_form csrf; br (); todo_list csrf todos ])
;;
