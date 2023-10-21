import gleam/dynamic
import gleam/map
import gleam/result
import migrant/types.{DatabaseError, Error, Migrations}
import sqlight

pub type QueryResult(a) =
  Result(List(a), Error)

pub fn exec(db: sqlight.Connection, sql: String) -> Result(Nil, Error) {
  sqlight.exec(sql, db)
  |> result.replace(Nil)
  |> result.map_error(DatabaseError)
}

pub fn query(
  db: sqlight.Connection,
  query sql: String,
  args args: List(sqlight.Value),
  decoder decoder: dynamic.Decoder(a),
) -> QueryResult(a) {
  sqlight.query(sql, db, args, decoder)
  |> result.map_error(DatabaseError)
}

pub fn create_migrations_table(
  db: sqlight.Connection,
  next: fn() -> Result(Nil, Error),
) -> Result(Nil, Error) {
  let query =
    "
    CREATE TABLE IF NOT EXISTS __migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  "

  case exec(db, query) {
    Ok(_) -> next()
    Error(e) -> Error(e)
  }
}

pub fn filter_applied_migrations(
  db: sqlight.Connection,
  migrations: Migrations,
  next: fn(Migrations) -> Result(Nil, Error),
) -> Result(Nil, Error) {
  let sql = "SELECT name FROM __migrations ORDER BY id, name ASC;"

  case query(db, sql, [], dynamic.string) {
    Ok(applied) ->
      migrations
      |> map.drop(drop: applied)
      |> next
    Error(e) -> Error(e)
  }
}
