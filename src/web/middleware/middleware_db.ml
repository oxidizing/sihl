module Make (Db : Data.Db.Service.Sig.SERVICE) = struct
  let m () =
    let filter handler ctx =
      let ctx = Db.add_pool ctx in
      handler ctx
    in
    Middleware_core.create ~name:"database" filter
end
