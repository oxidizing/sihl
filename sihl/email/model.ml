exception Exception of string

module Template = struct
  type t =
    { id : string
    ; name : string
    ; content_text : string
    ; content_html : string
    ; created_at : Ptime.t
          [@to_yojson Utils.Time.ptime_to_yojson] [@of_yojson Utils.Time.ptime_of_yojson]
    }
  [@@deriving yojson, show, eq, fields]

  let set_name name template = { template with name }
  let set_text content_text template = { template with content_text }
  let set_html content_html template = { template with content_html }

  let t =
    let encode m =
      Ok (m.id, (m.name, (m.content_text, (m.content_html, m.created_at))))
    in
    let decode (id, (name, (content_text, (content_html, created_at)))) =
      Ok { id; name; content_text; content_html; created_at }
    in
    Caqti_type.(
      custom ~encode ~decode (tup2 string (tup2 string (tup2 string (tup2 string ptime)))))
  ;;

  let make ?text ?html name =
    { id = Database.Id.random () |> Database.Id.to_string
    ; name
    ; content_text = text |> Option.value ~default:""
    ; content_html = html |> Option.value ~default:""
    ; created_at = Ptime_clock.now ()
    }
  ;;

  let replace_element str k v =
    let regexp = Str.regexp @@ "{" ^ k ^ "}" in
    Str.global_replace regexp v str
  ;;

  let render data template =
    let rec render_value data value =
      match data with
      | [] -> value
      | (k, v) :: data -> render_value data @@ replace_element value k v
    in
    let text = render_value data template.content_text in
    let html = render_value data template.content_html in
    text, html
  ;;

  module Data = struct
    type t = (string * string) list [@@deriving show, eq]

    let empty = []
    let add ~key ~value data = List.cons (key, value) data
    let make data = data
  end
end

type t =
  { sender : string
  ; recipient : string
  ; subject : string
  ; text_content : string
  ; html_content : string
  ; cc : string list
  ; bcc : string list
  ; html : bool
  ; template_id : string option
  ; template_data : (string * string) list
  }
[@@deriving yojson, show, eq, make, fields]

module DevInbox = struct
  let inbox : t option ref = ref None

  let get () =
    if Option.is_some !inbox then Logs.err (fun m -> m "no email found in dev inbox");
    Option.get !inbox
  ;;

  let set email = inbox := Some email
end

let set_text_content text_content email = { email with text_content }
let set_html_content html_content email = { email with html_content }
