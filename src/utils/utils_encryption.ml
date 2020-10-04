open Base

let xor str1 str2 =
  String.of_char_list
    (List.map2_exn
       ~f:(fun chr1 chr2 -> Char.of_int_exn (Char.to_int chr1 lxor Char.to_int chr2))
       (String.to_list str1)
       (String.to_list str2))
;;

let decrypt_with_salt ~salted_cipher ~salt_length =
  let salt = String.subo ~len:salt_length salted_cipher in
  let encrypted_value = String.sub ~pos:salt_length ~len:salt_length salted_cipher in
  xor salt encrypted_value
;;
