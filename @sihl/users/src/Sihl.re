module Persistence = SihlCore.SihlCoreDbCore.Make(SihlMysql.SihlMysql.Mysql);

module Core = {
  include SihlCore.SihlCore;
  include SihlCore.SihlCore.Make(Persistence);
};
