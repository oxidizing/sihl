module PIO = {
  open Rationale;

  type io('a, 'env) =
    | IO(Lazy.t('env => Js.Promise.t('a)));

  let runIO: (io('a, 'env), 'env) => Js.Promise.t('a) =
    (IO(f), env) => Lazy.force(f, env);

  let lift = fn => IO(lazy(fn));

  include Monad.MakeBasic2({
    type t('a, 'env) = io('a, 'env);
    let return = a => IO(lazy(_ => Js.Promise.resolve(a)));

    let bind = (iov: io('a, 'env), fn: 'a => io('b, 'c)) =>
      IO(
        lazy(
          env => {
            let a = runIO(iov, env);
            Js.Promise.then_(
              a => {
                let rb = fn(a);
                runIO(rb, env);
              },
              a,
            );
          }
        ),
      );
    let fmap = `DefineWithBind;
  });
};

module FIO = {
  open Rationale;

  type io('a, 'env, 'err) =
    | IO(Lazy.t('env => Future.t(Belt.Result.t('a, 'err))));

  let runIO: (io('a, 'env, 'err), 'env) => Future.t(Belt.Result.t('a, 'err)) =
    (IO(f), env) => Lazy.force(f, env);

  let lift = fn => IO(lazy(fn));

  include Monad.MakeBasic3({
    type t('a, 'env, 'err) = io('a, 'env, 'err);
    let return = a => IO(lazy(_ => Future.value(Belt.Result.Ok(a))));

    let bind = (iov: io('a, 'env, 'err), fn: 'a => io('b, 'c, 'd)) =>
      IO(
        lazy(
          env => {
            let a = runIO(iov, env);
            Future.flatMapOk(
              a,
              a => {
                let rb = fn(a);
                runIO(rb, env);
              },
            );
          }
        ),
      );
    let fmap = `DefineWithBind;
  });
};
