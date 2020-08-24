open Base

exception Exception of string

module Status = struct
  type t = Active | Inactive [@@deriving yojson, show, eq]

  let to_string = function Active -> "active" | Inactive -> "inactive"

  let of_string str =
    match str with
    | "active" -> Ok Active
    | "inactive" -> Ok Inactive
    | _ -> Error (Printf.sprintf "Invalid token status %s provided" str)
end

type t = {
  id : string;
  value : string;
  data : string option;
  kind : string;
  status : Status.t;
  expires_at : Ptime.t;
  created_at : Ptime.t;
}
[@@deriving fields, show, eq]

let make ~id ~data ~kind ?(expires_in = Utils.Time.OneDay) ?now () =
  let value = Utils.Random.base64 ~bytes:80 in
  let expires_in = Utils.Time.duration_to_span expires_in in
  let now = Option.value ~default:(Ptime_clock.now ()) now in
  let expires_at = Option.value_exn (Ptime.add_span now expires_in) in
  let status = Status.Active in
  { id; value; data; kind; status; expires_at; created_at = Ptime_clock.now () }

let alco = Alcotest.testable pp equal

let t =
  let encode m =
    let status = Status.to_string m.status in
    Ok
      ( m.id,
        (m.value, (m.data, (m.kind, (status, (m.expires_at, m.created_at))))) )
  in
  let decode (id, (value, (data, (kind, (status, (expires_at, created_at)))))) =
    match Status.of_string status with
    | Ok status -> Ok { id; value; data; kind; status; expires_at; created_at }
    | Error msg -> Error msg
  in
  Caqti_type.(
    custom ~encode ~decode
      (tup2 Data.Id.t_string
         (tup2 string
            (tup2 (option string)
               (tup2 string (tup2 string (tup2 ptime ptime)))))))
