type t =
  { map : Hmap.t
  ; id : int
  ; atomic_id : int option
  }

type 'a key = 'a Hmap.key

let id_counter = ref 0

let next_id () =
  (* Int will overflow, which is Ok since we want to generate IDs that live for a short
     period of time. It is very unlikely that there are roughly 2^32 request contexts
     active. *)
  id_counter := !id_counter + 1;
  !id_counter
;;

(* There should be about 100 transactions open at the same time *)
let atomic_f = Hashtbl.create 100
let empty () = { map = Hmap.empty; id = next_id (); atomic_id = None }

let atomic ctx f =
  let open Lwt.Syntax in
  match ctx.atomic_id with
  (* We are in an atomic context already, nothing to do *)
  | Some _ -> f ctx
  | None ->
    let id = next_id () in
    assert (Option.is_none (Hashtbl.find_opt atomic_f id));
    Hashtbl.add atomic_f id None;
    Lwt.finalize
      (fun () -> f { ctx with atomic_id = Some id })
      (fun () ->
        let* () =
          match Hashtbl.find_opt atomic_f id with
          | Some (Some f) -> f ()
          | _ ->
            (* No atomic implementation was registered, nothing to do *)
            Lwt.return ()
        in
        (* Every key added has to be removed finally *)
        Hashtbl.remove atomic_f id;
        Lwt.return ())
;;

let handle_atomic ctx start_atomic finalize_atomic =
  let open Lwt.Syntax in
  match ctx.atomic_id with
  | None -> Lwt.return None
  | Some atomic_id ->
    let* trx = start_atomic () in
    let finalize () = finalize_atomic trx in
    Hashtbl.add atomic_f atomic_id (Some finalize);
    Lwt.return (Some trx)
;;

let add key item ctx = { ctx with map = Hmap.add key item ctx.map }
let find key ctx = Hmap.find key ctx.map
let remove key ctx = { ctx with map = Hmap.rem key ctx.map }
let create_key = Hmap.Key.create
let id ctx = Digest.string (string_of_int ctx.id)
