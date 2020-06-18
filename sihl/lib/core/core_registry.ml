(* TODO rename to core_container.ml, provide more ergonomic API in bottom *)

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

module State = struct
  type t = { map : Hmap.t; is_initialized : bool }

  let state = ref { map = Hmap.empty; is_initialized = false }

  let set_initialized () = state := { !state with is_initialized = true }

  let set key impl = state := { !state with map = Hmap.add key impl !state.map }

  let get key = Hmap.find key !state.map

  let is_initialized () = !state.is_initialized
end

module Binding = struct
  type t = { binding : unit -> unit; repo : Sig.repo option }

  let get_repo binding = binding.repo

  let create key impl =
    { binding = (fun () -> State.set key impl); repo = None }

  let create_with_repo repo key impl =
    { binding = (fun () -> State.set key impl); repo }

  let apply binding = binding.binding ()

  let register key impl = create key impl |> apply
end

let fetch key =
  if State.is_initialized () then State.get key
  else
    failwith
      "REGISTRY: Registry was not initialized but someone tried to pull \
       bindings out of it. Have you forgot to put arguments on the left-hand \
       side of your function so that the registry gets accessed once the \
       module runs? "

let fetch_exn key =
  match fetch key with
  | Some implementation -> implementation
  | None ->
      let msg = "Implementation not found for " ^ Key.info key in
      let () = Logs.err (fun m -> m "REGISTRY: %s" msg) in
      failwith msg

type binding = Binding.t

let register = Binding.register

(* TODO remove *)
let bind = Binding.create

let create_binding key service repo = Binding.create_with_repo repo key service

let set_initialized = State.set_initialized
