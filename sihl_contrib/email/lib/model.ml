module Template = struct
  type t = { id : string; label : string; value : string; status : string }

  let value template = template.value

  let create ~label ~value = { id = "TODO"; label; value; status = "active" }
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
