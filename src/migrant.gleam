import argv
import gleam/bool
import gleam/io
import gleam/result
import migrant/config.{type Config, Config}
import migrant/error.{type MigrantError}
import simplifile

pub type MigrationFile {
  MigrationFile(path_parts: List(String), statement: String)
}

pub fn main() {
  case argv.load().arguments {
    ["new", migration_name] -> create_migration(migration_name)
    _ -> print_help()
  }
}

pub fn migrate(config: Config(_)) {
  todo
}

pub fn load_migration_files() -> Result(List(MigrationFile), MigrantError) {
  // TODO: get and sort all migration files
  todo
}

fn create_migration(migration_name: String) -> Nil {
  let parsed_config = config.parse_config_from_gleam_toml(debug: True)
  use <- bool.guard(when: result.is_error(parsed_config), return: {
    let assert Error(e) = parsed_config
    io.println_error(e)
  })

  // TODO: get last migraton and the numerical prefix

  Nil
}

fn print_help() -> Nil {
  "Migrant - minimal database migration tool for Gleam

Usage: gleam run -m migrant [command]

Commands:
  new <migration name> e.g `...new create_users_table`"
  |> io.println

  Nil
}
