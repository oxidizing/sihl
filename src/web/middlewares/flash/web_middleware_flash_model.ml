open Base

module Message = struct
  type t = Error of string | Warning of string | Success of string
  [@@deriving eq, show, yojson]

  let success txt = Success txt

  let warning txt = Warning txt

  let error txt = Error txt
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
