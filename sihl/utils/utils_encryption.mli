(** Encrypting plaintexts and ciphertext manipulation *)

(** [xor str1 str2] does bitwise XORing of [str1] and [str2]. Raises if non-ASCII
    characters are used or the two strings differ in length. *)
val xor : string -> string -> string

val decrypt_with_salt : salted_cipher:string -> salt_length:int -> string

(** [decrypt_with_salt ~salted_cipher ~salt_length] splits the prepended salt off of
    [salted_cipher] and uses it to XOR the rest of [salted_cipher]. Since [xor] is used,
    raises if the cipher and [salt_length] differ in length. *)
