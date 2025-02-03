type t =
  { id : string
  ; label : string
  ; language : string option
  ; text : string
  ; html : string option
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving eq, show]

let name = "email.template"

module type Sig = sig
  (** [get ?ctx id] returns the email template by [id]. *)
  val get : ?ctx:(string * string) list -> string -> t option Lwt.t

  (** [get_by_label ?ctx ?language label] returns the email template by [label]
      and optional [language]. *)
  val get_by_label
    :  ?ctx:(string * string) list
    -> ?language:string
    -> string
    -> t option Lwt.t

  (** [create ?ctx ?id ?html ?language label text] creates an email template
      with [text] as text email content and a [label]. An optional [html]
      content can be provided that will be displayed in email clients that
      support HTML and an optional [language] supports multiple content
      languages. *)
  val create
    :  ?ctx:(string * string) list
    -> ?id:string
    -> ?html:string
    -> ?language:string
    -> label:string
    -> string
    -> t Lwt.t

  (** [update ?ctx template] updates the email [template]. *)
  val update : ?ctx:(string * string) list -> t -> t Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

(* Common *)

let to_sexp { id; label; language; text; html; created_at; updated_at } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]
    ; List [ Atom "label"; sexp_of_string label ]
    ; List [ Atom "language"; sexp_of_option sexp_of_string language ]
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
    let language = json |> member "language" |> to_string_option in
    let text = json |> member "text" |> to_string in
    let html = json |> member "html" |> to_string_option in
    let created_at = json |> member "created_at" |> to_string in
    let updated_at = json |> member "updated_at" |> to_string in
    match Ptime.of_rfc3339 created_at, Ptime.of_rfc3339 updated_at with
    | Ok (created_at, _, _), Ok (updated_at, _, _) ->
      Some { id; label; language; text; html; created_at; updated_at }
    | _ -> None
  with
  | _ -> None
;;

let to_yojson template =
  `Assoc
    [ "id", `String template.id
    ; "label", `String template.label
    ; ( "language"
      , match template.language with
        | Some language -> `String language
        | None -> `Null )
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
let set_language language template = { template with language }

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
