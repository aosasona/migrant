import gleam/io
import gleam/map
import migrant/filesystem
import sqlight

pub fn migrate(_: sqlight.Connection, migration_dir: String) {
  let migrations = case filesystem.load_migration_files(migration_dir) {
    Ok(migrations) -> migrations
    Error(e) -> {
      io.debug(e)
      panic as "Failed to load migrations"
    }
  }

  io.print("Migrations found:")
  io.debug(
    migrations
    |> map.to_list,
  )

  Nil
}
