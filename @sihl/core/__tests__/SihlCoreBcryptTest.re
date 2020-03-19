open Jest;
open Expect;

module Async = SihlCoreAsync;

describe("Bcrypt", () => {
  testPromise("compares different passwords", () => {
    let%Async hash = SihlCoreBcrypt.hashAndSalt(~plain="foobar", ~rounds=1);
    let%Async isEqual = SihlCoreBcrypt.Hash.compare(~plain="123", ~hash);
    isEqual |> expect |> toBe(false) |> Async.async;
  });
  testPromise("compares same passwords", () => {
    let%Async hash = SihlCoreBcrypt.hashAndSalt(~plain="foobar", ~rounds=1);
    let%Async isEqual = SihlCoreBcrypt.Hash.compare(~plain="foobar", ~hash);
    isEqual |> expect |> toBe(true) |> Async.async;
  });
});
