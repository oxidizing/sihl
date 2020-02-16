// This file is designed to be opened for entire modules.

// Using Bluebird for the global promise implementation allows actually useful
// stack traces to be generated for debugging runtime issues.
%bs.raw
{|global.Promise = require('bluebird')|};
%bs.raw
{|
Promise.config({
  warnings: false
})
|};

let let_ = (p, cb) => Js.Promise.then_(cb, p);

let mapAsync = (p, cb) =>
  Js.Promise.then_(a => cb(a)->Js.Promise.resolve, p);

let async = a => Js.Promise.resolve(a);

type promise('a) = Js.Promise.t('a);

let catchAsync = (p, cb) => Js.Promise.catch(cb, p);

let asyncFromResult = result => {
  // Lift it into a promise in case the original caller wasn't arlready in the promise. We want to use Promise's error catching behavior, and not Javascript's error catching behavior.
  result
  ->async
  ->mapAsync(a => {
      switch (a) {
      | Ok(b) => b
      | Error(err) => Js.Exn.raiseError(err->Obj.magic)
      }
    });
};

let attemptMapAsync =
    (promise: Js.Promise.t('a), attempter: 'a => result('b, 'error))
    : Js.Promise.t('b) => {
  promise->mapAsync(a => {
    switch (attempter(a)) {
    | Ok(b) => b
    | Error(err) => Js.Exn.raiseError(err->Obj.magic)
    }
  });
};

let rec allInOrder = promises => {
  switch (promises) {
  | [p, ...ps] => let_(p, _ => allInOrder(ps))
  | [] => async()
  };
};

let wait: int => Js.Promise.t(unit) = [%raw
  {|
function(ms) {
  new Promise((res, rej) => {
    setTimeout(res, ms);
  })
}
|}
];
