open Base

module TemplateData = struct
  type t = (string * string) list [@@deriving show, eq]

  let empty = []

  let add ~key ~value data = List.cons (key, value) data

  let make data = data
end

module Template = struct
  type t = {
    id : string;
    label : string;
    content_text : string;
    content_html : string;
    status : string;
    created_at : Ptime.t;
  }
  [@@deriving show, eq, fields]

  let t =
    let encode m =
      Ok
        ( m.id,
          (m.label, (m.content_text, (m.content_html, (m.status, m.created_at))))
        )
    in
    let decode
        (id, (label, (content_text, (content_html, (status, created_at))))) =
      Ok { id; label; content_text; content_html; status; created_at }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 string
           (tup2 string (tup2 string (tup2 string (tup2 string ptime))))))

  let make ?text ?html label =
    {
      id = "TODO";
      label;
      content_text = text |> Option.value ~default:"";
      content_html = html |> Option.value ~default:"";
      status = "active";
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

let set_content content email = { email with content }

module type SERVICE = sig
  val send : Opium.Std.Request.t -> t -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.Key.t =
  Core.Container.Key.create "email.service"

let send req email =
  let (module Email : SERVICE) = Core.Container.fetch_exn key in
  Email.send req email
