open Base
open Sexplib

type t = {
  id : string;
  email : string;
  username : string option;
  password : string;
  status : string;
  admin : bool;
  confirmed : bool;
}

val t_of_sexp : Sexp.t -> t

val sexp_of_t : t -> Sexp.t

val confirmed : t -> bool

val admin : t -> bool

val status : t -> string

val password : t -> string

val username : t -> string option

val email : t -> string

val id : t -> string

module Fields : sig
  val names : string list

  val confirmed : ([< `Read | `Set_and_create ], t, bool) Field.t_with_perm

  val admin : ([< `Read | `Set_and_create ], t, bool) Field.t_with_perm

  val status : ([< `Read | `Set_and_create ], t, string) Field.t_with_perm

  val password : ([< `Read | `Set_and_create ], t, string) Field.t_with_perm

  val username :
    ([< `Read | `Set_and_create ], t, string option) Field.t_with_perm

  val email : ([< `Read | `Set_and_create ], t, string) Field.t_with_perm

  val id : ([< `Read | `Set_and_create ], t, string) Field.t_with_perm

  val make_creator :
    id:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
      'a ->
      ('b -> string) * 'c) ->
    email:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
      'c ->
      ('b -> string) * 'd) ->
    username:
      (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
      'd ->
      ('b -> string option) * 'e) ->
    password:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
      'e ->
      ('b -> string) * 'f) ->
    status:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
      'f ->
      ('b -> string) * 'g) ->
    admin:
      (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
      'g ->
      ('b -> bool) * 'h) ->
    confirmed:
      (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
      'h ->
      ('b -> bool) * 'i) ->
    'a ->
    ('b -> t) * 'i

  val create :
    id:string ->
    email:string ->
    username:string option ->
    password:string ->
    status:string ->
    admin:bool ->
    confirmed:bool ->
    t

  val map :
    id:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> string) ->
    email:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> string) ->
    username:
      (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
      string option) ->
    password:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> string) ->
    status:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> string) ->
    admin:(([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> bool) ->
    confirmed:
      (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> bool) ->
    t

  val iter :
    id:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> unit) ->
    email:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> unit) ->
    username:
      (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
      unit) ->
    password:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> unit) ->
    status:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> unit) ->
    admin:(([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> unit) ->
    confirmed:
      (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> unit) ->
    unit

  val fold :
    init:'a ->
    id:('a -> ([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'b) ->
    email:
      ('b -> ([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'c) ->
    username:
      ('c ->
      ([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
      'd) ->
    password:
      ('d -> ([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'e) ->
    status:
      ('e -> ([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'f) ->
    admin:
      ('f -> ([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> 'g) ->
    confirmed:
      ('g -> ([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> 'h) ->
    'h

  val map_poly : ([< `Read | `Set_and_create ], t, 'a) Field.user -> 'a list

  val for_all :
    id:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    email:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    username:
      (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
      bool) ->
    password:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    status:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    admin:(([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> bool) ->
    confirmed:
      (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> bool) ->
    bool

  val exists :
    id:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    email:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    username:
      (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
      bool) ->
    password:
      (([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    status:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> bool) ->
    admin:(([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> bool) ->
    confirmed:
      (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> bool) ->
    bool

  val to_list :
    id:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'a) ->
    email:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'a) ->
    username:
      (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm -> 'a) ->
    password:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'a) ->
    status:(([< `Read | `Set_and_create ], t, string) Field.t_with_perm -> 'a) ->
    admin:(([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> 'a) ->
    confirmed:(([< `Read | `Set_and_create ], t, bool) Field.t_with_perm -> 'a) ->
    'a list

  module Direct : sig
    val iter :
      t ->
      id:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        unit) ->
      email:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        unit) ->
      username:
        (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
        t ->
        string option ->
        unit) ->
      password:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        unit) ->
      status:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        unit) ->
      admin:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        unit) ->
      confirmed:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        'a) ->
      'a

    val fold :
      t ->
      init:'a ->
      id:
        ('a ->
        ([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'b) ->
      email:
        ('b ->
        ([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'c) ->
      username:
        ('c ->
        ([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
        t ->
        string option ->
        'd) ->
      password:
        ('d ->
        ([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'e) ->
      status:
        ('e ->
        ([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'f) ->
      admin:
        ('f ->
        ([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        'g) ->
      confirmed:
        ('g ->
        ([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        'h) ->
      'h

    val for_all :
      t ->
      id:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      email:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      username:
        (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
        t ->
        string option ->
        bool) ->
      password:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      status:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      admin:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        bool) ->
      confirmed:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        bool) ->
      bool

    val exists :
      t ->
      id:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      email:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      username:
        (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
        t ->
        string option ->
        bool) ->
      password:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      status:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        bool) ->
      admin:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        bool) ->
      confirmed:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        bool) ->
      bool

    val to_list :
      t ->
      id:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'a) ->
      email:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'a) ->
      username:
        (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
        t ->
        string option ->
        'a) ->
      password:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'a) ->
      status:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        'a) ->
      admin:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        'a) ->
      confirmed:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        'a) ->
      'a list

    val map :
      t ->
      id:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        string) ->
      email:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        string) ->
      username:
        (([< `Read | `Set_and_create ], t, string option) Field.t_with_perm ->
        t ->
        string option ->
        string option) ->
      password:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        string) ->
      status:
        (([< `Read | `Set_and_create ], t, string) Field.t_with_perm ->
        t ->
        string ->
        string) ->
      admin:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        bool) ->
      confirmed:
        (([< `Read | `Set_and_create ], t, bool) Field.t_with_perm ->
        t ->
        bool ->
        bool) ->
      t

    val set_all_mutable_fields : 'a -> unit
  end
end

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val confirm : t -> t

val update_password : t -> string -> t

val update_details : t -> email:string -> username:string option -> t

val is_admin : t -> bool

val is_owner : t -> string -> bool

val is_confirmed : t -> bool

val matches_password : string -> t -> bool

val validate_password : string -> (unit, string) Result.t

val validate :
  t -> old_password:string -> new_password:string -> (unit, string) Result.t

val create :
  email:string ->
  password:string ->
  username:string option ->
  admin:bool ->
  confirmed:bool ->
  t

val system : t
