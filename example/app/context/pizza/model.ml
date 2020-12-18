(* This defines our pizza model *)
(* These models are pure and are used by other parts of the application, like the services *)
type t =
  { id : string
  ; name : string
  ; ingredients : string list
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
(* We use some ppx for convenience *)
(* make is used to construct a pizza model from data fetched from the database *)
[@@deriving fields, show, eq, make]

(* This creates a pizza model with a randomized id *)
let create name ingredients =
  { id = Uuidm.v `V4 |> Uuidm.to_string
  ; name
  ; ingredients
  ; created_at = Ptime_clock.now ()
  ; updated_at = Ptime_clock.now ()
  }
;;
