type t('a) = {
  namespace: string,
  resource: string,
  encode: 'a => Js.Json.t,
  decode: Js.Json.t => Belt.Result.t('a, Decco.decodeError),
  fields: list(string),
};
