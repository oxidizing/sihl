module Async = Sihl.Core.Async;

type t =
  | AdminOneUserOneBoard;

let set = (db, seed) => {
  switch (seed) {
  | AdminOneUserOneBoard =>
    Sihl.Core.Main.Manager.seed(
      Sihl.Users.Seeds.set,
      Sihl.Users.Seeds.AdminOneUser,
    )
  /* Sihl.Core.Db.Database.withConnection(db, conn => { */
  /*   Service.Board.create((conn, "foo"), ~title="Foo board") */
  /* }); */
  };
};
