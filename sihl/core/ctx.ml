type t =
  { map : Hmap.t
  ; id : string
  }

type 'a key = 'a Hmap.key

let add key item ctx = { ctx with map = Hmap.add key item ctx.map }
let find key ctx = Hmap.find key ctx.map
let remove key ctx = { ctx with map = Hmap.rem key ctx.map }
let create_key = Hmap.Key.create
let id ctx = ctx.id
let sexp_of_t t = Sexplib.Std.sexp_of_string t.id

let create ?id () =
  match id with
  | Some id -> { map = Hmap.empty; id }
  | None ->
    let id = Random.bytes ~nr:32 |> List.to_seq |> String.of_seq in
    { map = Hmap.empty; id }
;;

(* TODO [jerben] add functions that support context logging *)
