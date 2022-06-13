(* TODO consider moving this to Sihl.View *)

let html_to_string (html : Tyxml.Html.doc) : string =
  Format.asprintf "%a" (Tyxml.Html.pp ()) html
;;

let form
    (type a)
    ?(on_invalid : Dream.request -> a Form.invalid -> unit Lwt.t =
      fun _ _ -> Lwt.return ())
    (on_valid : Dream.request -> a -> unit Lwt.t)
    (success_url : Dream.request -> string Lwt.t)
    (form : a Form.default)
    (template : Dream.request -> a Form.t -> Tyxml.Html.doc)
    : string -> Dream.route
  =
 fun url ->
  let get =
    Dream.get url (fun request ->
        Dream.html (html_to_string (template request (Default form))))
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

let create () : string -> Dream.route =
 fun url -> Dream.get url (fun _ -> Dream.respond "foo")
;;

let list () : string -> Dream.route =
 fun url -> Dream.get url (fun _ -> Dream.respond "foo")
;;

let details () : string -> Dream.route =
 fun url -> Dream.get url (fun _ -> Dream.respond "foo")
;;

let reverse ?(params : (string * string) list = []) (url : string) =
  params |> ignore;
  url |> ignore;
  failwith "reverse()"
;;

let message_success = "success"
let message_danger = "danger"
let message_warning = "warning"
let message_info = "info"
