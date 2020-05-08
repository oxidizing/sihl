open Base

module Hmap = Hmap.Make (struct
  type 'a t = string
end)

module Key = struct
  type 'a t = 'a Hmap.key

  let create = Hmap.Key.create

  let info = Hmap.Key.info
end

let state = ref Hmap.empty

module Binding : sig
  type t

  val create : 'a Hmap.key -> 'a -> t

  val apply : t -> unit

  val register : 'a Hmap.key -> 'a -> unit
end = struct
  type t = unit -> unit

  let create key impl () =
    state := Hmap.add key impl !state;
    ()

  let apply binding = binding ()

  let register key impl = create key impl |> apply
end

let get key =
  match Hmap.find key !state with
  | Some implementation -> implementation
  | None ->
      let _ =
        Logs.err (fun m -> m "implementation not found for %s" (Key.info key))
      in
      failwith @@ "implementation not found for " ^ Key.info key

let register = Binding.register

let bind = Binding.create
