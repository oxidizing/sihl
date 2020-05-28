open Base

module Message = struct
  type t = Error of string | Warning of string | Success of string
  [@@deriving eq, show, yojson]
end

module Entry = struct
  type t = { current : Message.t option; next : Message.t option }
  [@@deriving eq, show, yojson]

  let create message = { current = None; next = Some message }

  let current entry = entry.current

  let next entry = entry.next

  let rotate entry = { current = entry.next; next = None }

  let to_string entry = entry |> to_yojson |> Yojson.Safe.to_string

  let of_string str = str |> Yojson.Safe.from_string |> of_yojson
end

(* Tests *)

let%test "entry to and from string" =
  let entry = Entry.create (Error "foo") in
  Entry.equal
    (entry |> Entry.to_string |> Entry.of_string |> Result.ok_or_failwith)
    entry
