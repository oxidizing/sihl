let insert (db : Config.database) (model : 'a Model.t)
    : ('a, int, [ `One ]) Caqti_request.t
  =
  db |> ignore;
  model |> ignore;
  Obj.magic ()
;;
