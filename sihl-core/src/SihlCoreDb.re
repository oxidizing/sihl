module Connection = {
  type t = int;
  let make = () => 0;
};

module ConnectionPool = {
  type t;

  let getConnection = () => Connection.make();
};
