open Base

let ( let* ) = Lwt.bind

type t = Error of string | Warning of string | Success of string
[@@deriving sexp]

let pp fmt (flash : t) =
  let s =
    match flash with
    | Error msg -> msg
    | Warning msg -> msg
    | Success msg -> msg
  in
  Caml.Format.pp_print_string fmt s

let equal f1 f2 =
  match (f1, f2) with
  | Success msg1, Success msg2 -> String.equal msg1 msg2
  | Warning msg1, Warning msg2 -> String.equal msg1 msg2
  | Error msg1, Error msg2 -> String.equal msg1 msg2
  | _ -> false

module Store = struct
  type entry = { current : t option; next : t option } [@@deriving sexp]

  type t = (string, entry, String.comparator_witness) Map.t

  (* TODO consider using bounded Hashtable or the database
     instead of an unbounded immutable map *)
  let state = ref @@ Map.empty (module String)

  let add ~id flash =
    match
      Map.add !state ~key:id ~data:{ current = None; next = Some flash }
    with
    | `Duplicate ->
        Logs.err (fun m ->
            m "failed to create unique key to store flash message");
        Core_err.raise_server
          "failed to create unique key to store flash message"
    | `Ok map ->
        state := map;
        ()

  let rotate id =
    let entry = Map.find !state id in
    match entry with
    | None -> ()
    | Some entry ->
        let entry = { current = entry.next; next = None } in
        state := Map.set !state ~key:id ~data:entry

  let remove id =
    state := Map.remove !state id;
    ()

  let has id = Map.find !state id |> Option.is_some

  let find_current id =
    Map.find !state id |> Option.bind ~f:(fun flash -> flash.current)

  let is_next_set id =
    Map.find !state id
    |> Option.value_map ~default:false ~f:(fun entry ->
           Option.is_some entry.next)

  let set_next ~id flash =
    state :=
      Map.update !state id ~f:(fun entry ->
          match entry with
          | Some entry -> { entry with next = Some flash }
          | None -> { next = Some flash; current = None })
end

let key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("flash id", fun _ -> sexp_of_string "flash id")

let current req =
  let flash_id = req |> Http.Req.env |> Opium.Hmap.find key in
  match flash_id with
  | None ->
      Logs.warn (fun m ->
          m
            "FLASH: No flash message found, have you applied the flash \
             middleware?");
      None
  | Some flash_id -> Store.find_current flash_id

let set req flash =
  let flash_id = req |> Http.Req.env |> Opium.Hmap.find key in
  match flash_id with
  | None ->
      let flash_id = Uuidm.v `V4 |> Uuidm.to_string in
      Store.add ~id:flash_id flash |> ignore
  | Some flash_id -> Store.set_next ~id:flash_id flash |> ignore

let set_success req txt = set req (Success txt)

let set_error req txt = set req (Error txt)

let cookie_key = "flash_id"

let m () =
  let filter handler req =
    let flash_id = Opium.Std.Cookie.get req ~key:cookie_key in
    match flash_id with
    | None ->
        let flash_id = Uuidm.v `V4 |> Uuidm.to_string in
        let env = Opium.Hmap.add key flash_id (Http.Req.env req) in
        let* resp = handler { req with env } in
        if Store.is_next_set flash_id then
          resp |> Http.Cookie.set ~key:cookie_key ~data:flash_id |> Lwt.return
        else resp |> Lwt.return
    | Some flash_id ->
        if Store.has flash_id then
          let env = Opium.Hmap.add key flash_id (Http.Req.env req) in
          let () = Store.rotate flash_id in
          let* resp = handler { req with env } in
          if Store.is_next_set flash_id then
            resp |> Http.Cookie.set ~key:cookie_key ~data:flash_id |> Lwt.return
          else
            let () = Store.remove flash_id in
            resp |> Http.Cookie.unset ~key:cookie_key |> Lwt.return
        else
          let* resp = handler req in
          resp |> Http.Cookie.unset ~key:cookie_key |> Lwt.return
  in

  Opium.Std.Rock.Middleware.create ~name:"flash" ~filter

(* convenience helper functions *)

let redirect_with_error req ~path txt =
  set_error req txt;
  Http.Res.empty |> Http.Res.redirect path |> Lwt.return

let redirect_with_success req ~path txt =
  set_success req txt;
  Http.Res.empty |> Http.Res.redirect path |> Lwt.return
