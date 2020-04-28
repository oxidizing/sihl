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

let bind key implementation = state := Hmap.add key implementation !state

let get key =
  match Hmap.find key !state with
  | Some implementation -> implementation
  | None ->
      let _ =
        Logs.info (fun m -> m "implementation not found for %s" (Key.info key))
      in
      failwith @@ "implementation not found for " ^ Key.info key

type bind = unit -> unit list
