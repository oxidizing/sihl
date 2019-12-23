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
