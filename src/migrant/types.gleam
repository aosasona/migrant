import gleam/dict.{type Dict}
import gleam/option.{type Option}
import simplifile
import sqlight

pub type Error {
  ExpectedFolderError
  FileError(simplifile.FileError)
  FilenameError(message: String)
  ExtractionError(message: String)
  DatabaseError(sqlight.Error)
  MigrationError(message: String, err: Error)
}

pub type Migration {
  Migration(up: Option(String), down: Option(String))
}

pub type Migrations =
  Dict(String, Migration)
