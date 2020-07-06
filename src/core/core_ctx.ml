type t = { map : Hmap.t; id : string }

type 'a key = 'a Hmap.key

let empty = { map = Hmap.empty; id = Data_id.random () |> Data_id.to_string }

let add key item ctx = { ctx with map = Hmap.add key item ctx.map }

let find key ctx = Hmap.find key ctx.map

let remove key ctx = { ctx with map = Hmap.rem key ctx.map }

let create_key = Hmap.Key.create

let id ctx = ctx.id
