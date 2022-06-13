let html_to_string (html : Tyxml.Html.doc) : string =
  Format.asprintf "%a" (Tyxml.Html.pp ()) html
;;

let template
    ?(context = fun _ -> Lwt.return None)
    (template : 'a option -> Dream.request -> Tyxml.Html.doc Lwt.t)
    : string -> Dream.route
  =
 fun url ->
  Dream.get url (fun req ->
      let%lwt ctx = context req in
      let%lwt template = template ctx req in
      Dream.html (html_to_string template))
;;

let form
    (type a b)
    ?(context : Dream.request -> b option Lwt.t = fun _ -> Lwt.return None)
    ?(on_invalid : Dream.request -> a Form.invalid -> unit Lwt.t =
      fun _ _ -> Lwt.return ())
    (on_valid : Dream.request -> a -> unit Lwt.t)
    (success_url : Dream.request -> string Lwt.t)
    (form : a Form.unsafe)
    (template : Dream.request -> b option -> a Form.t -> Tyxml.Html.doc)
    : (Dream.method_ * Dream.handler) list
  =
  let get req =
    let%lwt ctx = context req in
    Dream.html (html_to_string (template req ctx (Unsafe form)))
  in
  let post req =
    match%lwt Dream.form req with
    | `Ok form_data ->
      (match Form.validate form form_data with
      | Ok (a, _) ->
        let%lwt () = on_valid req a in
        let%lwt success_url = success_url req in
        Dream.redirect req success_url
      | Error form ->
        let%lwt () = on_invalid req form in
        Dream.empty `Bad_Request)
    | _ -> Dream.empty `Bad_Request
  in
  [ `GET, get; `POST, post ]
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
    (type a b)
    ?(context : (Dream.request -> b option Lwt.t) option)
    ?(on_valid : Dream.request -> a Model.t -> a -> unit Lwt.t =
      create_on_valid_default)
    (model : a Model.t)
    (success_url : Dream.request -> string Lwt.t)
    (template : Dream.request -> b option -> a Form.t -> Tyxml.Html.doc)
    : (Dream.method_ * Dream.handler) list
  =
  let on_valid req a = on_valid req model a in
  let model_form = Form.of_model model in
  form ?context on_valid success_url model_form template
;;

let list
    (type a b)
    ?(context : Dream.request -> b option Lwt.t = fun _ -> Lwt.return None)
    ?(model : a Model.t option)
    ?(query : a Query.read option)
    (template : Dream.request -> b option -> a list -> Tyxml.Html.doc)
    : (Dream.method_ * Dream.handler) list
  =
  [ ( `GET
    , fun req ->
        let%lwt a_list =
          Dream.sql req (fun conn ->
              match model, query with
              | Some model, _ -> Query.(all model |> find_all conn)
              | None, Some query -> Query.find_all conn query
              | None, None ->
                failwith "list view needs either a model or a query")
        in
        let%lwt ctx = context req in
        Dream.html (html_to_string (template req ctx a_list)) )
  ]
;;

let detail
    (type a b)
    ?(context : Dream.request -> b option Lwt.t = fun _ -> Lwt.return None)
    ?(pk = "pk")
    ?(model : a Model.t option)
    ?(query : a Query.read option)
    (template : Dream.request -> b option -> a -> Tyxml.Html.doc)
    : (Dream.method_ * Dream.handler) list
  =
  [ ( `GET
    , fun req ->
        let pk = int_of_string (Dream.param req pk) in
        let%lwt _, a =
          Dream.sql req (fun conn ->
              match model, query with
              | Some model, _ ->
                Query.(
                  all model
                  |> where_int (Model.field_int "id") eq pk
                  |> find conn)
              | None, Some query -> Query.find conn query
              | None, None ->
                failwith "detail view needs either a model or a query")
        in
        let%lwt ctx = context req in
        Dream.html (html_to_string (template req ctx a)) )
  ]
;;

let reverse ?(params : (string * string) list = []) (url : string) =
  List.fold_left (fun a (k, v) -> CCString.replace ~sub:k ~by:v a) url params
;;

let message_success = "success"
let message_danger = "danger"
let message_warning = "warning"
let message_info = "info"
