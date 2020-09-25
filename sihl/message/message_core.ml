module Message = struct
  type t = {
    error : string list;
    warning : string list;
    success : string list;
    info : string list;
  }
  [@@deriving eq, show, yojson]

  let empty = { error = []; warning = []; success = []; info = [] }

  let set_success txts message = { message with success = txts }

  let set_warning txts message = { message with warning = txts }

  let set_error txts message = { message with error = txts }

  let set_info txts message = { message with info = txts }

  let get_error message = message.error

  let get_warning message = message.warning

  let get_success message = message.success

  let get_info message = message.info

  let ctx_key : t Core.Ctx.key = Core.Ctx.create_key ()

  let ctx_add message ctx = Core.Ctx.add ctx_key message ctx

  let get ctx = Core.Ctx.find ctx_key ctx
end

module Entry = struct
  type t = { current : Message.t option; next : Message.t option }
  [@@deriving eq, show, yojson]

  let create message = { current = None; next = Some message }

  let empty = { current = None; next = None }

  let current entry = entry.current

  let next entry = entry.next

  let set_next message entry = { entry with next = Some message }

  let set_current message entry = { entry with current = Some message }

  let rotate entry = { current = entry.next; next = None }

  let to_string entry = entry |> to_yojson |> Yojson.Safe.to_string

  let of_string str = str |> Yojson.Safe.from_string |> of_yojson
end
