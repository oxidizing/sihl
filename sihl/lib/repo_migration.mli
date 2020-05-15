module MariaDbRepository : Core.Contract.Migration.REPOSITORY

module PostgresRepository : Core.Contract.Migration.REPOSITORY

val execute : Core.Contract.Migration.migration list -> (unit, string) result Lwt.t
