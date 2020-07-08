let m () =
  let filter handler ctx =
    let ctx = Data.Db.add_pool ctx in
    handler ctx
  in
  Web_middleware_core.create ~name:"database" filter
