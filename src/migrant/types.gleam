import gleam/map.{Map}
import gleam/option.{Option}
import simplifile

pub type MigrationError {
  ExpectedFolderError
  FileError(simplifile.FileError)
  FilenameError(message: String)
  ExtractionError(message: String)
}

pub type Migration {
  Migration(up: Option(String), down: Option(String))
}

pub type Migrations =
  Map(String, Migration)
