let html_to_string (html : Tyxml.Html.doc) : string =
  Format.asprintf "%a" (Tyxml.Html.pp ()) html
;;

let form
    (type a)
    ?(on_invalid : Dream.request -> a Form.invalid -> unit Lwt.t =
      fun _ _ -> Lwt.return ())
    (on_valid : Dream.request -> a -> unit Lwt.t)
    (success_url : Dream.request -> string Lwt.t)
    (form : a Form.unsafe)
    (template : Dream.request -> a Form.t -> Tyxml.Html.doc)
    : string -> Dream.route
  =
 fun url ->
  let get =
    Dream.get url (fun request ->
        Dream.html (html_to_string (template request (Unsafe form))))
  in
  let post =
    Dream.post url (fun request ->
        match%lwt Dream.form request with
        | `Ok form_data ->
          (match Form.validate form form_data with
          | Ok (a, _) ->
            let%lwt () = on_valid request a in
            let%lwt success_url = success_url request in
            Dream.redirect request success_url
          | Error form ->
            let%lwt () = on_invalid request form in
            Dream.empty `Bad_Request)
        | _ -> Dream.empty `Bad_Request)
  in
  Dream.scope "/" [] [ get; post ]
;;

let create_on_valid_default
    (request : Dream.request)
    (model : 'a Model.t)
    (a : 'a)
    : unit Lwt.t
  =
  Dream.sql request (fun conn -> Query.(insert model a |> execute conn))
  |> Lwt.map ignore
;;

let create
    (type a)
    ?(on_valid : Dream.request -> a Model.t -> a -> unit Lwt.t =
      create_on_valid_default)
    (model : a Model.t)
    (success_url : Dream.request -> string Lwt.t)
    (template : Dream.request -> a Form.t -> Tyxml.Html.doc)
    : string -> Dream.route
  =
  let on_valid req a = on_valid req model a in
  let model_form = Form.of_model model in
  fun url -> form on_valid success_url model_form template url
;;

let list
    (type a)
    ?(model : a Model.t option)
    ?(query : a Query.read option)
    (template : Dream.request -> a list -> Tyxml.Html.doc)
    : string -> Dream.route
  =
 fun url ->
  Dream.get url (fun req ->
      let%lwt a_list =
        Dream.sql req (fun conn ->
            match model, query with
            | Some model, _ -> Query.(all model |> find_all conn)
            | None, Some query -> Query.find_all conn query
            | None, None ->
              failwith "Sihl.View.list needs either a model or a query")
      in
      Dream.respond (html_to_string (template req a_list)))
;;

let detail
    (type a)
    ?(pk = "pk")
    ?(model : a Model.t option)
    ?(query : a Query.read option)
    (template : Dream.request -> a -> Tyxml.Html.doc)
    : string -> Dream.route
  =
 fun url ->
  Dream.get url (fun req ->
      let pk = int_of_string (Dream.param req pk) in
      let%lwt _, a =
        Dream.sql req (fun conn ->
            match model, query with
            | Some model, _ ->
              Query.(all model |> where_int (field_int "id") eq pk |> find conn)
            | None, Some query -> Query.find conn query
            | None, None ->
              failwith "Sihl.View.list needs either a model or a query")
      in
      Dream.respond (html_to_string (template req a)))
;;

let reverse ?(params : (string * string) list = []) (url : string) =
  List.fold_left (fun a (k, v) -> CCString.replace ~sub:k ~by:v a) url params
;;

let message_success = "success"
let message_danger = "danger"
let message_warning = "warning"
let message_info = "info"
