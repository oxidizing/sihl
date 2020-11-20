open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  val get : id:string -> Email_template.t option Lwt.t
  val get_by_name : name:string -> Email_template.t option Lwt.t
  val create : name:string -> html:string -> text:string -> Email_template.t Lwt.t
  val update : template:Email_template.t -> Email_template.t Lwt.t
  val render : Email.t -> Email.t Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
