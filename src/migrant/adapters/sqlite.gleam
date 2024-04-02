import migrant/error.{type MigrantError}
import sqlight.{type Connection}

pub fn connect(
  dsn: String,
  next: fn(Connection) -> Result(a, MigrantError),
) -> Result(a, MigrantError) {
  case sqlight.open(dsn) {
    Ok(conn) -> next(conn)
    Error(e) -> Error(error.SQliteError(e))
  }
}

pub fn get_migrations(conn: Connection) -> Result(List(String), String) {
  todo
}

pub fn execute(conn: Connection, query: String) -> Result(Nil, String) {
  todo
}
