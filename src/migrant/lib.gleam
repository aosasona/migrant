import gleam/map
import gleam/option.{None}
import migrant/types.{FilenameError, Migration, MigrationError, Migrations}

pub fn get_or_make_migration(
  name: String,
  migrations: Migrations,
  next: fn(Migration) -> Result(#(String, Migration), MigrationError),
) -> Result(#(String, Migration), MigrationError) {
  case map.get(migrations, name) {
    Ok(migration) -> next(migration)
    Error(_) -> next(Migration(None, None))
  }
}

pub fn validate_direction(
  direction: String,
  next: fn(String) -> Result(#(String, Migration), MigrationError),
) -> Result(#(String, Migration), MigrationError) {
  case direction {
    "up" -> next("up")
    "down" -> next("down")
    _ -> Error(FilenameError("Expected `up` or `down`"))
  }
}
