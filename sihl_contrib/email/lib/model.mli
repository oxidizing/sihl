module Template : sig
  type t

  val t : t Caqti_type.t

  val value : t -> string

  val create : ?text:string -> ?html:string -> string -> t
end

module Email : sig
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

  val create :
    sender:string ->
    recipient:string ->
    subject:string ->
    content:string ->
    cc:string list ->
    bcc:string list ->
    html:bool ->
    template_id:string option ->
    template_data:(string * string) list ->
    t

  val replace_element : string -> string -> string -> string

  val render : (string * string) list -> Template.t -> string
end
