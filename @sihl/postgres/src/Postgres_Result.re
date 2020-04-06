[@decco]
type t = {
  rows: list(Js.Json.t),
  fields: list(Js.Json.t),
  rowCount: int,
  command: string,
};
let decode = Sihl.Common.Error.Decco.stringifyDecoder(t_decode);
