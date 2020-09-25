(** Use this module to verify whether a user is who the user claims to be. *)

(** {1 Installation}

{[
module Repo = Sihl.Data.Repo.Service.Make ()
module Random = Sihl.Utils.Random.Make ()
module Cmd = Sihl.Cmd.Service.Make ()
module Log = Sihl.Log.Service.Make ()
module Db = Sihl.Data.Db.Service (Config) (Log)
module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakeMariaDb (Db)
module Migration = Sihl.Data.Migration.Service.Make (Log) (Cmd) (Db) (MigrationRepo)

(* Repo *)
module SessionRepo =
  Sihl.Session.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)
module UserRepo = Sihl.User.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)

(* Service *)
module Session = Sihl.Session.Service.Make (Log) (Random) (SessionRepo)
module User = Sihl.User.Service.Make (Log) (Cmd) (Db) (UserRepo)
]}
*)

(** {1 Usage}

(* TODO *)

*)

module Service = Authn_service
