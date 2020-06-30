type t = Hmap.t

type 'a key = 'a Hmap.key

let empty = Hmap.empty

let add = Hmap.add

let find = Hmap.find

let remove = Hmap.rem

let create_key = Hmap.Key.create
