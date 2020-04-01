module Async = SihlCoreAsync;

let devInbox: Pervasives.ref(option(SihlCoreEmailCore.t)) = ref(None);

let getLastEmail = () => devInbox^;

module Nodemailer = {
  module Email = {
    [@bs.deriving abstract]
    type t = {
      from: string,
      [@bs.as "to"]
      to_: string,
      [@bs.optional]
      bcc: string,
      [@bs.optional]
      subject: string,
      [@bs.optional]
      text: string,
      [@bs.optional]
      html: string,
    };

    let make = t;
  };

  module Config = {
    type auth = {
      .
      "user": string,
      "pass": string,
    };

    [@bs.deriving abstract]
    type t = {
      host: string,
      port: int,
      secure: bool,
      pool: bool,
      [@bs.optional]
      auth,
    };

    let make = t;
  };

  module Transport = {
    type t;
    [@bs.module "nodemailer"]
    external create: Config.t => t = "createTransport";
    [@bs.send] external send: (t, Email.t) => Js.Promise.t(unit) = "sendMail";
    [@bs.send] external verify: t => Js.Promise.t(unit) = "verify";

    let make = (~host, ~port, ~secure, ~auth, ~pool, ()) => {
      Config.make(~host, ~port, ~secure, ~auth, ~pool, ()) |> create;
    };
  };
};

let send = (email: SihlCoreEmailCore.t) =>
  switch (SihlCoreConfig.get(~default="console", "EMAIL_BACKEND")) {
  | "smtp" =>
    let recipient = email.recipient;
    let email =
      Nodemailer.Email.make(
        ~from=email.sender,
        ~to_=email.recipient,
        ~subject=email.subject,
        ~text=email.text,
        (),
      );
    let transport =
      Nodemailer.Transport.make(
        ~host=SihlCoreConfig.get("SMTP_HOST"),
        ~port=SihlCoreConfig.getInt("SMTP_PORT"),
        ~auth={
          "user": SihlCoreConfig.get("SMTP_AUTH_USERNAME"),
          "pass": SihlCoreConfig.get("SMTP_AUTH_PASSWORD"),
        },
        ~secure=SihlCoreConfig.getBool("SMTP_SECURE"),
        ~pool=SihlCoreConfig.getBool(~default=false, "SMTP_POOL"),
        (),
      );
    Nodemailer.Transport.send(transport, email)
    ->Async.mapAsync(_ =>
        SihlCoreLog.info(
          "email sent using smtp backend recipient=" ++ recipient,
          (),
        )
      );
  | "console" =>
    Async.async @@ SihlCoreLog.info(SihlCoreEmailCore.toString(email), ())
  | _ =>
    devInbox := Some(email);
    Async.async();
  };
