open Sihl_contract.Email_template
open Sihl_core.Container

let to_sexp { id; label; text; html; created_at; updated_at } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]
    ; List [ Atom "label"; sexp_of_string label ]
    ; List [ Atom "text"; sexp_of_string text ]
    ; List [ Atom "html"; sexp_of_option sexp_of_string html ]
    ; List [ Atom "created_at"; sexp_of_string (Ptime.to_rfc3339 created_at) ]
    ; List [ Atom "updated_at"; sexp_of_string (Ptime.to_rfc3339 updated_at) ]
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)

let of_yojson json =
  let open Yojson.Safe.Util in
  try
    let id = json |> member "id" |> to_string in
    let label = json |> member "label" |> to_string in
    let text = json |> member "text" |> to_string in
    let html = json |> member "html" |> to_string_option in
    let created_at = json |> member "created_at" |> to_string in
    let updated_at = json |> member "updated_at" |> to_string in
    match Ptime.of_rfc3339 created_at, Ptime.of_rfc3339 updated_at with
    | Ok (created_at, _, _), Ok (updated_at, _, _) ->
      Some { id; label; text; html; created_at; updated_at }
    | _ -> None
  with
  | _ -> None
;;

let to_yojson template =
  `Assoc
    [ "id", `String template.id
    ; "label", `String template.label
    ; "text", `String template.text
    ; ( "html"
      , match template.html with
        | Some html -> `String html
        | None -> `Null )
    ; "created_at", `String (Ptime.to_rfc3339 template.created_at)
    ; "updated_at", `String (Ptime.to_rfc3339 template.updated_at)
    ]
;;

let set_label label template = { template with label }
let set_text text template = { template with text }
let set_html html template = { template with html }

let replace_element str k v =
  let regexp = Str.regexp @@ "{" ^ k ^ "}" in
  Str.global_replace regexp v str
;;

let render data text html =
  let rec render_value data value =
    match data with
    | [] -> value
    | (k, v) :: data -> render_value data @@ replace_element value k v
  in
  let text = render_value data text in
  let html = Option.map (render_value data) html in
  text, html
;;

let email_of_template ?template email data =
  let text, html =
    match template with
    | Some template -> render data template.text template.html
    | None ->
      let open Sihl_contract.Email in
      render data email.text email.html
  in
  email |> Email.set_text text |> Email.set_html html |> Lwt.return
;;

let instance : (module Sig) option ref = ref None

let get id =
  let module Service = (val unpack name instance : Sig) in
  Service.get id
;;

let get_by_label name =
  let module Service = (val unpack name instance : Sig) in
  Service.get_by_label name
;;

let create ?html ~label text =
  let module Service = (val unpack name instance : Sig) in
  Service.create ?html ~label text
;;

let update template =
  let module Service = (val unpack name instance : Sig) in
  Service.update template
;;

let lifecycle () =
  let module Service = (val unpack name instance : Sig) in
  Service.lifecycle
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;
