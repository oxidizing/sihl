type t =
  { id : string
  ; label : string
  ; text : string
  ; html : string option
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }

let name = "email.template"

module type Sig = sig
  val get : string -> t option Lwt.t
  val get_by_label : string -> t option Lwt.t
  val create : ?html:string -> label:string -> string -> t Lwt.t
  val update : t -> t Lwt.t
  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

(* Common *)

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

(* TODO Deprecate in later version *)
(* [@@deprecated "Use Sihl_email.Template.render_email_with_data() instead"] *)

let email_of_template ?template (email : Contract_email.t) data =
  let text, html =
    match template with
    | Some template -> render data template.text template.html
    | None -> render data email.text email.html
  in
  email
  |> Contract_email.set_text text
  |> Contract_email.set_html html
  |> Lwt.return
;;

(* TODO Deprecate in later version *)
(* [@@deprecated "Use Sihl_email.Template.render_email() instead"] *)

let create_email_of_template
    ?(cc = [])
    ?(bcc = [])
    ~sender
    ~recipient
    ~subject
    template
    data
  =
  (* Create an empty mail, the content is rendered *)
  let email = Contract_email.create ~cc ~bcc ~sender ~recipient ~subject "" in
  let text, html = render data template.text template.html in
  email |> Contract_email.set_text text |> Contract_email.set_html html
;;

let render_email_with_data data (email : Contract_email.t) =
  let text, html = render data email.text email.html in
  { email with text; html }
;;
