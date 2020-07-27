type cleaner = Core.Ctx.t -> (unit, string) Result.t Lwt.t

module Meta = struct
  type t = { total : int } [@@deriving show, eq, fields, make]
end

module Dynparam = struct
  type t = Pack : 'a Caqti_type.t * 'a -> t

  let empty = Pack (Caqti_type.unit, ())

  let add t x (Pack (t', x')) = Pack (Caqti_type.tup2 t' t, (x', x))
end
