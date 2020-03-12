module Async = Sihl.Core.Async;

let board = (~user, ~title, conn) =>
  Service.Board.create((conn, user), ~title);

let issue = (~board, ~user, ~title, ~description, conn) =>
  Service.Issue.create((conn, user), ~title, ~description, ~board);
