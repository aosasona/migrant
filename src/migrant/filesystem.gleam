import gleam/string
import gleam/map
import gleam/option.{None, Option, Some}
import migrant/types.{
  Error, ExpectedFolderError, ExtractionError, FileError, Migration, Migrations,
}
import migrant/lib
import simplifile

pub fn load_migration_files(
  migrations_dir: String,
  next: fn(Migrations) -> Result(Nil, Error),
) -> Result(Nil, Error) {
  use migrations_dir <- is_directory(migrations_dir)
  use files <- list_files(migrations_dir)

  case parse_files(migrations_dir, files, map.new()) {
    Ok(migrations) -> next(migrations)
    Error(e) -> Error(e)
  }
}

fn is_directory(path: String, next: fn(String) -> Result(Nil, Error)) {
  case simplifile.is_directory(path) {
    True -> next(path)
    False -> Error(ExpectedFolderError)
  }
}

fn list_files(path: String, next: fn(List(String)) -> Result(Nil, Error)) {
  case simplifile.list_contents(path) {
    Ok(files) -> next(files)
    Error(e) -> Error(FileError(e))
  }
}

fn read_file(path: String, filename: String) -> Option(String) {
  let filepath = case string.ends_with(path, "/") {
    True -> path <> filename
    False -> path <> "/" <> filename
  }

  case simplifile.read(filepath) {
    Ok(contents) -> Some(string.trim(contents))
    Error(_) -> None
  }
}

fn parse_files(
  migrations_dir: String,
  files: List(String),
  migrations: Migrations,
) -> Result(Migrations, Error) {
  case files {
    [] -> Ok(migrations)
    [file, ..rest] -> {
      let res = case
        file
        |> string.split(".")
      {
        [name, direction, "sql"] -> {
          use direction <- lib.validate_direction(direction)
          use migration <- lib.get_or_make_migration(name, migrations)
          let sql = read_file(migrations_dir, file)

          let migration = case direction {
            "up" -> Migration(..migration, up: sql)
            "down" -> Migration(..migration, down: sql)
          }

          Ok(#(name, migration))
        }
        _ -> {
          Error(ExtractionError(
            "Failed to extract up/down from " <> file <> ". Migration files must be named in the format <name>.<up/down>.sql e.g 00001_create_users.up.sql",
          ))
        }
      }

      case res {
        Ok(#(name, migration)) -> {
          let migrations = map.insert(migrations, name, migration)
          parse_files(migrations_dir, rest, migrations)
        }
        Error(e) -> Error(e)
      }
    }
  }
}
