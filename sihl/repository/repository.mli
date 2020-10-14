(** The repository service deals with cleaning repositories. This is useful for
    integration tests. *)

(** {1 Installation}

    Use the provided {!Sihl.Repository.Service.Make} to instantiate a repo service.

    {[ module Repo = Sihl.Repository.Service.Make () ]} *)

module Service : Sig.SERVICE

(** {1 Usage}

    You typically want to use the repo service in your own repositories in order to
    register repository cleaners. This allows Sihl to reset the state of your system after
    integration tests.

    [{ let cleaner = ... in Repo.register_cleaer cleaner; }]

    In order to clean all repositories that have registered cleaners you can call
    [clean_all]:

    [{ open Lwt.Syntax let* () = Repo.clean_all ctx in .. }] *)

(** Repositories can return meta data containing information like total rows affected.
    This can be useful for pagination. *)
module Meta = Model.Meta

(** This module can be used to assemble dynamic repository queries. This is typically used
    if you don't know the number of parameters at compile time because they are provided
    by the user, for instance as a filter or sort.
    {:http://paurkedal.github.io/ocaml-caqti/caqti/Caqti_request/index.html#how-to-dynamically-assemble-queries-and-parameters} *)
module Dynparam = Model.Dynparam

module Sig = Sig
