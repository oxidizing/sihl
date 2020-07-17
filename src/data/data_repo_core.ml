type cleaner = Data_db_core.connection -> (unit, string) Result.t Lwt.t

module Meta = struct
  type t = { total : int } [@@deriving show, eq, fields, make]
end
