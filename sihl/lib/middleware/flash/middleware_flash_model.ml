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

(* Tests *)

let%test "entry to and from string" =
  let entry = Entry.create (Error "foo") in
  Entry.equal
    (entry |> Entry.to_string |> Entry.of_string |> Result.ok_or_failwith)
    entry

let%test "rotate once" =
  let msg = Message.Success "foo" in
  let entry = Entry.create msg |> Entry.rotate in
  let is_current_set =
    entry |> Entry.current
    |> Option.map ~f:(Message.equal msg)
    |> Option.value ~default:false
  in
  let is_next_none = Option.is_none (entry |> Entry.next) in
  is_current_set && is_next_none

let%test "rotate twice" =
  let entry = Entry.create (Success "foo") in
  Entry.equal Entry.empty (entry |> Entry.rotate |> Entry.rotate)
