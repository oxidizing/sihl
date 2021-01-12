(* The model encapsulates business rules expressed as types and pure functions.

   The functions are easy to test. Try to squeeze as many business rules as
   possible in here. Make sure to not do any side effects here. If you are
   using Lwt.t here, consider moving that part into the service.
*)

type status =
  | Active
  | Done

type t =
  { id : string
  ; description : string
  ; status : status
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }

let create description =
  { id = Uuidm.v `V4 |> Uuidm.to_string
  ; description
  ; status = Active
  ; created_at = Ptime_clock.now ()
  ; updated_at = Ptime_clock.now ()
  }
;;
