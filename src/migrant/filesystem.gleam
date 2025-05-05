import gleam/bool
import gleam/dict
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import migrant/lib
import migrant/types.{
  type Error, type Migrations, ExpectedFolderError, ExtractionError, FileError,
  Migration,
}
import simplifile

pub fn load_migration_files(
  migrations_dir: String,
  next: fn(Migrations) -> Result(Nil, Error),
) -> Result(Nil, Error) {
  io.println("-> Loading migrations from " <> migrations_dir)
  use migrations_dir <- is_directory(migrations_dir)
  use files <- list_files(migrations_dir)

  case parse_files(migrations_dir, files, dict.new()) {
    Ok(migrations) -> next(migrations)
    Error(e) -> Error(e)
  }
}

fn is_directory(path: String, next: fn(String) -> Result(Nil, Error)) {
  use is_dir <- result.try(
    simplifile.is_directory(path)
    |> result.map_error(FileError),
  )
  use <- bool.guard(when: is_dir, return: next(path))
  Error(ExpectedFolderError)
}

fn list_files(path: String, next: fn(List(String)) -> Result(Nil, Error)) {
  use files <- result.try(
    simplifile.read_directory(path)
    |> result.map_error(FileError),
  )

  next(files)
}

fn read_file(path: String, filename: String) -> Option(String) {
  let file_path = {
    use <- bool.guard(
      when: string.ends_with(path, "/"),
      return: path <> filename,
    )

    path <> "/" <> filename
  }

  case simplifile.read(file_path) {
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
      let res = case string.split(file, ".") {
        [name, direction, "sql"] -> {
          use direction <- lib.validate_direction(direction)
          use migration <- lib.get_or_make_migration(name, migrations)
          let sql = read_file(migrations_dir, file)

          let migration = case direction {
            "up" -> Some(Migration(..migration, up: sql))
            "down" -> Some(Migration(..migration, down: sql))
            _ -> None
          }

          case migration {
            Some(m) -> Ok(#(name, m))
            None ->
              Error(ExtractionError(
                "Invalid migration direction, expected one of `up` or `down`, got `"
                <> direction
                <> "`",
              ))
          }
        }
        _ -> {
          Error(ExtractionError(
            "Failed to extract up/down from "
            <> file
            <> ". Migration files must be named in the format <name>.<up/down>.sql e.g 00001_create_users.up.sql",
          ))
        }
      }

      case res {
        Ok(#(name, migration)) -> {
          let migrations = dict.insert(migrations, name, migration)
          parse_files(migrations_dir, rest, migrations)
        }
        Error(e) -> Error(e)
      }
    }
  }
}
