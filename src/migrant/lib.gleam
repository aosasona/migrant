import gleam/dict
import gleam/option.{None}
import migrant/types.{
  type Error, type Migration, type Migrations, FilenameError, Migration,
}

pub fn get_or_make_migration(
  name: String,
  migrations: Migrations,
  next: fn(Migration) -> Result(#(String, Migration), Error),
) -> Result(#(String, Migration), Error) {
  case dict.get(migrations, name) {
    Ok(migration) -> next(migration)
    Error(_) -> next(Migration(None, None))
  }
}

pub fn validate_direction(
  direction: String,
  next: fn(String) -> Result(#(String, Migration), Error),
) -> Result(#(String, Migration), Error) {
  case direction {
    "up" -> next("up")
    "down" -> next("down")
    _ -> Error(FilenameError("Expected format <migraton_name>.<up/down>.sql"))
  }
}
