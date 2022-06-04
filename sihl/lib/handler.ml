module Map = Map.Make (String)

type context = string Map.t

let template _ = Obj.magic ()

let user_from_request (_ : Dream.request) =
  User.AuthenticatedUser
    { id = 0
    ; email = "hello@example.org"
    ; short_name = "short"
    ; full_name = "full"
    ; role = User.Superuser
    ; created_at = Obj.magic ()
    ; updated_at = Obj.magic ()
    }
;;

let list
    ?(model : 'a Model.t option)
    ?(query : 'a Query.t option)
    (render :
      User.request_user
      -> 'a list
      -> Dream.request
      -> [> Html_types.html ] Tyxml_html.elt Lwt.t)
    (request : Dream.request)
  =
  match model, query with
  | None, None -> failwith "handler_list needs either ~model or ~query"
  | _ ->
    let user : User.request_user = user_from_request request in
    let%lwt model_list = Model.list_of_model model in
    let%lwt response_html = render user model_list request in
    response_html |> Format.asprintf "%a" (Tyxml.Html.pp ()) |> Dream.html
;;

let detail _ = Obj.magic ()

let form
    ?(form : Form.t option)
    (template : Html_types.html Tyxml_html.elt)
    (request : Dream.request)
  =
  form |> ignore;
  request |> ignore;
  template |> ignore;
  Dream.html ""
;;
