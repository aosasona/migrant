import gleam/map.{Map}
import gleam/option.{Option}
import simplifile
import sqlight

pub type Error {
  ExpectedFolderError
  FileError(simplifile.FileError)
  FilenameError(message: String)
  ExtractionError(message: String)
  DatabaseError(sqlight.Error)
}

pub type Migration {
  Migration(up: Option(String), down: Option(String))
}

pub type Migrations =
  Map(String, Migration)
