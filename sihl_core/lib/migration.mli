module MariaDbRepository : Contract.Migration.REPOSITORY

module PostgresRepository : Contract.Migration.REPOSITORY

val execute : Contract.Migration.migration list -> (unit, string) result Lwt.t
