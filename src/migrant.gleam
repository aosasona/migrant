import gleam/io
import gleam/result
import migrant/database
import migrant/filesystem
import migrant/types.{type Error}
import sqlight

pub fn migrate(
  db: sqlight.Connection,
  migration_dir: String,
) -> Result(Nil, Error) {
  use <- database.create_migrations_table(db)
  use migrations <- filesystem.load_migration_files(migration_dir)
  use migrations <- database.filter_applied_migrations(db, migrations)

  database.apply_migrations(db, migrations)
  |> result.map(fn(_) {
    io.println("-> Migrations applied successfully")
    Nil
  })
}
