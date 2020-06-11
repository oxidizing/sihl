module Meta = struct
  type t = { total : int } [@@deriving show, eq, fields, make]
end

module Migration = Repo_migration

let hex_to_uuid uuid =
  Printf.sprintf "%s-%s-%s-%s-%s" (Caml.String.sub uuid 0 8)
    (Caml.String.sub uuid 8 4)
    (Caml.String.sub uuid 12 4)
    (Caml.String.sub uuid 16 4)
    (Caml.String.sub uuid 20 12)
  |> Base.String.lowercase
