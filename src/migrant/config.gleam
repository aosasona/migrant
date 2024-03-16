import sqlight

pub const migrations_table = "__migrations"

pub type Adapter(conn) {
  SQLiteAdapter(connection: sqlight.Connection)

  CustomAdapter(
    driver: conn,
    /// This function should return a list of migration names obtained directly from the table named `config.migrations_table` in the database.
    /// > The names should be ordered by the `id` column in ascending order. You can also use the `get_migrations_query` function to get the default query.
    get_migrations: fn(conn) -> Result(List(String), String),
    /// This function should be able to execute DDL statements and return an error if something goes wrong. The query is passed as a string to this function and it should be executed as is.
    execute: fn(conn, String) -> Result(Nil, String),
  )
}

pub type Path {
  /// If you want to use a single string path like "/path/to/migrations", handling the various path separators is up to you
  FullPath(String)

  /// If you want to use a split path like ["path", "to", "migrations"], this is guaranted to work across unix and windows, it is internally converted to a string
  SplitPath(List(String))
}

pub type Config(a) {
  Config(adapter: Adapter(a), path: Path)
}

/// Returns the `get_migrations` DDL statement to be used by custom adapters, and also used internally
pub fn get_migrations_query() -> String {
  "SELECT name FROM " <> migrations_table <> "ORDER BY id, name ASC"
}

/// Returns the `create_migrations` DDL statement to be used by custom adapters, also used internally
pub fn create_migrations_table() -> String {
  "CREATE TABLE "
  <> migrations_table
  <> " (id INT PRIMARY KEY AUTOINCREMENT, name VARCHAR(255) NOT NULL)"
}
