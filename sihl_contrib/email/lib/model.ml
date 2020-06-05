module Template = struct
  type t = {
    id : string;
    label : string;
    content : string;
    status : string;
    created_at : Ptime.t;
  }

  let t =
    let encode m =
      Ok (m.id, (m.label, (m.content, (m.status, m.created_at))))
    in
    let decode (id, (label, (content, (status, created_at)))) =
      Ok { id; label; content; status; created_at }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 string (tup2 string (tup2 string (tup2 string ptime)))))

  let value template = template.content

  let create ~label ~content =
    {
      id = "TODO";
      label;
      content;
      status = "active";
      created_at = Ptime_clock.now ();
    }
end

module Email = struct
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

  let create ~sender ~recipient ~subject ~content ~cc ~bcc ~html ~template_id
      ~template_data =
    {
      sender;
      recipient;
      subject;
      content;
      cc;
      bcc;
      html;
      template_id;
      template_data;
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
    render_value data (Template.value template)
end
