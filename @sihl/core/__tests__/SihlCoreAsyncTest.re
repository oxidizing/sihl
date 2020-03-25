open Jest;
open Expect;

describe("Async", () => {
  testPromise("allInOrder() executes functions in order", () => {
    open Sihl.Core.Async;
    let actual = ref([]);
    let first = () =>
      wait(50)->mapAsync(_ => actual := Belt.List.add(actual^, 3));
    let second = () =>
      wait(100)->mapAsync(_ => actual := Belt.List.add(actual^, 2));
    let third = () =>
      wait(0)->mapAsync(_ => actual := Belt.List.add(actual^, 1));
    let allInOrder = fns => allInOrder(fns)->mapAsync(_ => actual^);
    let%SihlCoreAsync result = allInOrder([first, second, third]);
    result |> expect |> toEqual([1, 2, 3]) |> async;
  })
});
