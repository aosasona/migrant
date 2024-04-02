import sqlight
import simplifile

pub type MigrantError {
  SimplifileError(simplifile.FileError)
  SQliteError(sqlight.Error)
}
