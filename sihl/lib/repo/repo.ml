module Meta = struct
  type t = { total : int } [@@deriving show, eq, fields, make]
end

let set_fk_check connection status =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  let request =
    Caqti_request.exec Caqti_type.bool
      {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}
  in
  Connection.exec request status
