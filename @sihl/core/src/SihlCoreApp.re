type t('database, 'endpoint, 'cliCommand) = {
  name: string,
  namespace: string,
  routes: 'database => list('endpoint),
  migration: SihlCoreDbCore.Migration.t,
  commands: list('cliCommand),
};
