open Base

module Hmap = Hmap.Make (struct
  type 'a t = string
end)

module Key = struct
  type 'a t = 'a Hmap.key

  let create = Hmap.Key.create

  let info = Hmap.Key.info
end

type 'a key = 'a Key.t

let create_key = Key.create

module State = struct
  type t = {
    map : Hmap.t;
    is_initialized : bool;
    services : (module Sig.SERVICE) list;
  }

  let state = ref { map = Hmap.empty; is_initialized = false; services = [] }

  let set_initialized () = state := { !state with is_initialized = true }

  let set key impl generic_service =
    let map = Hmap.add key impl !state.map in
    let services = List.concat [ !state.services; [ generic_service ] ] in
    state := { !state with map; services }

  let get key = Hmap.find key !state.map

  let get_services () = !state.services

  let is_initialized () = !state.is_initialized
end

module Binding = struct
  type t = { binding : unit -> unit; service : (module Sig.SERVICE) }

  let create key service generic_service =
    {
      binding = (fun () -> State.set key service generic_service);
      service = generic_service;
    }

  let register binding = binding.binding ()

  let get_service binding = binding.service
end

type binding = Binding.t

let fetch_service key =
  if State.is_initialized () then State.get key
  else
    failwith
      "REGISTRY: Registry was not initialized but someone tried to pull \
       bindings out of it. Have you forgot to put arguments on the left-hand \
       side of your function so that the registry gets accessed once the \
       module runs? "

let fetch_service_exn key =
  match fetch_service key with
  | Some implementation -> implementation
  | None ->
      let msg = "Implementation not found for " ^ Key.info key in
      let () = Logs.err (fun m -> m "REGISTRY: %s" msg) in
      failwith msg

let create_binding = Binding.create

let register = Binding.register

let set_initialized = State.set_initialized

let bind_services ctx service_bindings =
  let rec bind ctx service_bindings =
    match service_bindings with
    | binding :: service_bindings ->
        let (module Service : Sig.SERVICE) = Binding.get_service binding in
        Lwt_result.bind (Service.on_bind ctx) (fun _ ->
            bind ctx service_bindings)
    | [] -> Lwt_result.return ()
  in
  bind ctx service_bindings |> Lwt_result.map set_initialized

let start_services ctx =
  let rec start ctx services =
    match services with
    | (module Service : Sig.SERVICE) :: services ->
        Lwt_result.bind (Service.on_start ctx) (fun _ -> start ctx services)
    | [] -> Lwt_result.return ()
  in
  let services = State.get_services () in
  start ctx services

(* TODO remove*)
let bind = bind_services
