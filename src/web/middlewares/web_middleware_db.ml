module Make (Db : Data_db_sig.SERVICE) = struct
  let m () =
    let filter handler ctx =
      let ctx = Db.add_pool ctx in
      handler ctx
    in
    Web_middleware_core.create ~name:"database" filter
end
