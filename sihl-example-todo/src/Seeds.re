module Async = Sihl.Core.Async;

let board = (~user, ~title, conn) =>
  Service.Board.create((conn, user), ~title);
