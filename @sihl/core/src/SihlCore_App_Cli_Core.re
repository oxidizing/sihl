module Async = SihlCore_Common.Async;

type command('a) = {
  name: string,
  description: string,
  f: ('a, list(string), string) => Async.t(unit),
};
