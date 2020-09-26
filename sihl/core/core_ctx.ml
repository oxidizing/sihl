type t = { map : Hmap.t; id : string }

type 'a key = 'a Hmap.key

(* TODO [jerben] generate random id for ctx *)
let empty = { map = Hmap.empty; id = "randomid" }

let add key item ctx = { ctx with map = Hmap.add key item ctx.map }

let find key ctx = Hmap.find key ctx.map

let remove key ctx = { ctx with map = Hmap.rem key ctx.map }

let create_key = Hmap.Key.create

let id ctx = ctx.id
