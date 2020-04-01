open Jest;
open Expect;

module Async = SihlCoreAsync;

describe("Bcrypt", () => {
  open Sihl.Core.Crypt.Bcrypt;
  testPromise("compares different passwords", () => {
    let%Async hash = hashAndSalt(~plain="foobar", ~rounds=1);
    let%Async isEqual = Hash.compare(~plain="123", ~hash);
    isEqual |> expect |> toBe(false) |> Async.async;
  });
  testPromise("compares same passwords", () => {
    let%Async hash = hashAndSalt(~plain="foobar", ~rounds=1);
    let%Async isEqual = Hash.compare(~plain="foobar", ~hash);
    isEqual |> expect |> toBe(true) |> Async.async;
  });
});

describe("Random", () => {
  open! Sihl.Core.Crypt.Random;
  testPromise("generates random base64 string", () => {
    let%Async randomString = base64(30);
    randomString |> Js.String.length |> expect |> toBe(40) |> Async.async;
  });
  testPromise("generates random base64 string without special chars", () => {
    let%Async randomString = base64(200, ~specialChars=false);
    let hasNoSpecialChars =
      !Js.String.includes("/", randomString)
      && !Js.String.includes("+", randomString)
      && !Js.String.includes("=", randomString);
    hasNoSpecialChars |> expect |> toBe(true) |> Async.async;
  });
});
