module Meta = struct
  type t = { total : int } [@@deriving show, eq, fields, make]
end

module Migration = Repo_migration
