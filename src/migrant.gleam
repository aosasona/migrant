import gleam/io
import migrant/filesystem
import migrant/database
import migrant/types.{Error}
import sqlight

pub fn migrate(
  db: sqlight.Connection,
  migration_dir: String,
) -> Result(Nil, Error) {
  use <- database.create_migrations_table(db)
  use migrations <- filesystem.load_migration_files(migration_dir)
  use migrations <- database.filter_applied_migrations(db, migrations)

  case database.apply_migrations(db, migrations) {
    Ok(_) -> Ok(Nil)
    Error(err) -> {
      io.debug(err)
      panic as "Something went horribly wrong, see above for details."
    }
  }
}
