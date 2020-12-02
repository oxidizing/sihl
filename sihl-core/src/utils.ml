module Jwt = struct
  type algorithm = Jwto.algorithm =
    | HS256
    | HS512
    | Unknown

  type t = Jwto.t
  type payload = (string * string) list

  let empty = []
  let add_claim ~key ~value payload = List.cons (key, value) payload

  let set_expires_in ~now duration payload =
    let span = Time.duration_to_span duration in
    let epoch_s =
      Ptime.add_span now span |> Option.map Ptime.to_float_s |> Option.map Float.to_string
    in
    match epoch_s with
    | Some epoch_s -> add_claim ~key:"exp" ~value:epoch_s payload
    | None -> payload
  ;;

  let encode algorithm ~secret payload = Jwto.encode algorithm secret payload
  let decode ~secret token = Jwto.decode_and_verify secret token
  let get_claim ~key token = token |> Jwto.get_payload |> Jwto.get_claim key

  let is_expired ~now ?(claim = "exp") token =
    let is_ealier =
      let ( let* ) = Option.bind in
      let* claim = get_claim ~key:claim token in
      let* exp = Float.of_string_opt claim in
      let* exp = Ptime.of_float_s exp in
      Option.some (Ptime.is_earlier exp ~than:now)
    in
    Option.value is_ealier ~default:false
  ;;

  let pp = Jwto.pp
  let eq = Jwto.eq

  module Jwto = Jwto
end

module Json = struct
  type t = Yojson.Safe.t

  let parse str =
    try Ok (str |> Yojson.Safe.from_string) with
    | _ -> Error "failed to parse json"
  ;;

  let parse_opt str =
    try Some (str |> Yojson.Safe.from_string) with
    | _ -> None
  ;;

  let parse_exn str = str |> Yojson.Safe.from_string
  let to_string = Yojson.Safe.to_string

  module Yojson = Yojson.Safe
end

module Regex = struct
  type t = Re.Pcre.regexp

  let of_string string = Re.Pcre.regexp string
  let test regexp string = Re.Pcre.pmatch ~rex:regexp string

  let extract_last regexp text =
    let ( let* ) = Option.bind in
    let extracts = Array.to_list (Re.Pcre.extract ~rex:regexp text) in
    let* extracts =
      try Some (List.tl extracts) with
      | _ -> None
    in
    try Some (List.hd extracts) with
    | _ -> None
  ;;

  module Re = Re
end

module Hashing = struct
  let hash ?count plain =
    match count, not (Configuration.is_production ()) with
    | _, true -> Ok (Bcrypt.hash ~count:4 plain |> Bcrypt.string_of_hash)
    | Some count, false ->
      if count < 4 || count > 31
      then Error "Password hashing count has to be between 4 and 31"
      else Ok (Bcrypt.hash ~count plain |> Bcrypt.string_of_hash)
    | None, false -> Ok (Bcrypt.hash ~count:10 plain |> Bcrypt.string_of_hash)
  ;;

  let matches ~hash ~plain = Bcrypt.verify plain (Bcrypt.hash_of_string hash)

  module Bcrypt = Bcrypt
end

module String = struct
  let strip_chars s cs =
    let len = Caml.String.length s in
    let res = Bytes.create len in
    let rec aux i j =
      if i >= len
      then Bytes.to_string (Bytes.sub res 0 j)
      else if Caml.String.contains cs s.[i]
      then aux (succ i) j
      else (
        Bytes.set res j s.[i];
        aux (succ i) (succ j))
    in
    aux 0 0
  ;;
end

module Encryption = struct
  let xor c1 c2 =
    try
      Some
        (List.map2 (fun chr1 chr2 -> Char.chr (Char.code chr1 lxor Char.code chr2)) c1 c2)
    with
    | exn ->
      Logs.err (fun m ->
          m
            "XOR: Failed to XOR %s and %s. %s"
            (c1 |> List.to_seq |> Caml.String.of_seq)
            (c2 |> List.to_seq |> Caml.String.of_seq)
            (Printexc.to_string exn));
      None
  ;;

  let decrypt_with_salt ~salted_cipher ~salt_length =
    if List.length salted_cipher - salt_length != salt_length
    then (
      Logs.err (fun m ->
          m
            "ENCRYPT: Failed to decrypt cipher %s. Salt length does not match cipher \
             length."
            (salted_cipher |> List.to_seq |> Caml.String.of_seq));
      None)
    else (
      try
        let salt = CCList.take salt_length salted_cipher in
        let encrypted_value = CCList.drop salt_length salted_cipher in
        xor salt encrypted_value
      with
      | exn ->
        Logs.err (fun m ->
            m
              "ENCRYPT: Failed to decrypt cipher %s. %s"
              (salted_cipher |> List.to_seq |> Caml.String.of_seq)
              (Printexc.to_string exn));
        None)
  ;;
end
