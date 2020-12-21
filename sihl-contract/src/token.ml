module Data = struct
  type t = { user_id : string } [@@deriving yojson, make, fields]
end

module Status = struct
  type t =
    | Active
    | Inactive
  [@@deriving yojson, show, eq]

  let to_string = function
    | Active -> "active"
    | Inactive -> "inactive"
  ;;

  let of_string str =
    match str with
    | "active" -> Ok Active
    | "inactive" -> Ok Inactive
    | _ -> Error (Printf.sprintf "Invalid token status %s provided" str)
  ;;
end

type t =
  { id : string
  ; value : string
  ; data : string option
  ; kind : string
  ; status : Status.t
  ; expires_at : Ptime.t
  ; created_at : Ptime.t
  }
[@@deriving fields, show, eq]

let make ~id ~value ~data ~kind ~status ~expires_at ~created_at =
  { id; value; data; kind; status; expires_at; created_at }
;;

let invalidate token = { token with status = Inactive }

let is_valid token =
  Status.equal token.status Status.Active
  && Ptime.is_later token.expires_at ~than:(Ptime_clock.now ())
;;

(* Signature *)
exception Exception of string

let name = "sihl.service.token"

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Create a token and store a token.

      Provide [expires_in] to define a duration in which the token is valid, default is
      one day. Provide [data] to store optional data as string. Provide [length] to define
      the length of the token in bytes. *)
  val create
    :  kind:string
    -> ?data:string
    -> ?expires_in:Sihl_core.Time.duration
    -> ?length:int
    -> unit
    -> t Lwt.t

  (** Returns an active and non-expired token. Raises [Failure] if no token is found. *)
  val find : string -> t Lwt.t

  (** Returns an active and non-expired token. *)
  val find_opt : string -> t option Lwt.t

  (** Returns an active and non-expired token by id. Raises [Failure] if no token is
      found. *)
  val find_by_id : string -> t Lwt.t

  (** Returns an active and non-expired token by id. *)
  val find_by_id_opt : string -> t option Lwt.t

  (** Invalidate a token by marking it as such in the database and therefore marking it
      "to be deleted" *)
  val invalidate : t -> unit Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
