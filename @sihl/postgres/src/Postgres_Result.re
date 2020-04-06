module Query = {
  [@decco]
  type t = (list(Js.Json.t), Js.Json.t);
  let decode = Sihl.Common.Error.Decco.stringifyDecoder(t_decode);

  module MetaData = {
    [@decco]
    type t = {
      [@decco.key "FOUND_ROWS()"]
      totalCount: int,
    };

    let foundRowsQuery = "SELECT FOUND_ROWS();";
  };
};

module Execution = {
  [@decco]
  type meta = {
    fieldCount: int,
    affectedRows: int,
    insertId: int,
    info: string,
    serverStatus: int,
    warningStatus: int,
  };

  [@decco]
  type t = (meta, unit);
  let decode = Sihl.Common.Error.Decco.stringifyDecoder(t_decode);
};
