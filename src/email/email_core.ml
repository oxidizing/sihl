module Template = struct
  type t = {
    id : string;
    name : string;
    content_text : string;
    content_html : string;
    created_at : Ptime.t;
  }
  [@@deriving show, eq, fields]

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
      custom ~encode ~decode
        (tup2 string (tup2 string (tup2 string (tup2 string ptime)))))

  let make ?text ?html name =
    {
      id = Data.Id.random () |> Data.Id.to_string;
      name;
      content_text = text |> Option.value ~default:"";
      content_html = html |> Option.value ~default:"";
      created_at = Ptime_clock.now ();
    }

  let replace_element str k v =
    let regexp = Str.regexp @@ "{" ^ k ^ "}" in
    Str.global_replace regexp v str

  let render data template =
    let rec render_value data value =
      match data with
      | [] -> value
      | (k, v) :: data -> render_value data @@ replace_element value k v
    in
    render_value data template.content_text

  module Data = struct
    type t = (string * string) list [@@deriving show, eq]

    let empty = []

    let add ~key ~value data = List.cons (key, value) data

    let make data = data
  end
end

type t = {
  sender : string;
  recipient : string;
  subject : string;
  content : string;
  cc : string list;
  bcc : string list;
  html : bool;
  template_id : string option;
  template_data : (string * string) list;
}
[@@deriving show, eq, make, fields]

module DevInbox = struct
  let inbox : t option ref = ref None

  let get () =
    if Option.is_some !inbox then
      Logs.err (fun m -> m "no email found in dev inbox");
    Base.Option.value_exn ~message:"no email found in dev inbox" !inbox

  let set email = inbox := Some email
end

let set_content content email = { email with content }
