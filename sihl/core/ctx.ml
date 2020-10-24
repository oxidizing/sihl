type t =
  { map : Hmap.t
  ; id : string
  }

type 'a key = 'a Hmap.key

(* TODO [jerben] generate random id for ctx *)
let empty = { map = Hmap.empty; id = "randomid" }
let add key item ctx = { ctx with map = Hmap.add key item ctx.map }
let find key ctx = Hmap.find key ctx.map
let remove key ctx = { ctx with map = Hmap.rem key ctx.map }
let create_key = Hmap.Key.create
let id ctx = ctx.id
let sexp_of_t t = Sexplib.Std.sexp_of_string t.id
let counter = ref 0

let create ?id () =
  match id with
  | Some id -> { map = Hmap.empty; id }
  | None ->
    counter := !counter + 1;
    (* Increase counter and calculate md5 hash for consistent id length *)
    let id = Digest.string (string_of_int !counter) in
    { map = Hmap.empty; id }
;;
