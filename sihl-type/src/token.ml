exception Exception of string

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
