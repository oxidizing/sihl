open Tyxml.Html

let add csrf =
  form
    ~a:[ a_method `Post; a_action (uri_of_string "/add") ]
    [ p
        [ label [ txt "Description" ]
        ; br ()
        ; input
            ~a:
              [ a_input_type `Text
              ; a_name "description"
              ; a_placeholder "Do laundry"
              ]
            ()
        ]
    ; p [ input ~a:[ a_input_type `Hidden; a_name "csrf"; a_value csrf ] () ]
    ; button [ span [ txt "Add" ] ]
    ]
;;

let list csrf todos =
  let open Tyxml.Html in
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
                             ~a:
                               [ a_method `Post
                               ; a_action (uri_of_string "/do")
                               ]
                             [ input
                                 ~a:
                                   [ a_input_type `Hidden
                                   ; a_name "csrf"
                                   ; a_value csrf
                                   ]
                                 ()
                             ; input
                                 ~a:
                                   [ a_input_type `Hidden
                                   ; a_name "id"
                                   ; a_value id
                                   ]
                                 ()
                             ; button [ span [ txt "Do" ] ]
                             ]
                         ])
                   ]
               ])
           todos)
    ]
;;
