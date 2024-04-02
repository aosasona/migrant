import gleam/bool
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import sqlight
import tom

pub const migrations_table = "__migrations"

type BuiltinDriver {
  SQLite
}

type MigrantConfig {
  MigrantConfig(driver: BuiltinDriver, dsn: String, migrations_path: String)
}

pub type Adapter(conn) {
  SQLiteAdapter(connection: sqlight.Connection)

  CustomAdapter(
    // The connection for the database itself (e.g. pgo.Connection)
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

  /// If you want to use a split path like ["path", "to", "migrations"], this is guaranteed to work across unix and windows, it is internally converted to a string
  SplitPath(List(String))
}

pub type Config(a) {
  Config(adapter: Adapter(a), migrations_directory: Path)
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

pub fn parse_config_from_gleam_toml(
  debug debug: Bool,
) -> Result(Config(a), String) {
  use content <- read_gleam_toml(debug)
  use config <- parse_gleam_toml(content)
  use adapter <- connect(config)

  Ok(Config(
    adapter: adapter,
    migrations_directory: FullPath(config.migrations_path),
  ))
}

fn connect(
  config: MigrantConfig,
  next: fn(Adapter(a)) -> Result(Config(a), String),
) -> Result(Config(a), String) {
  case config.driver {
    SQLite ->
      case sqlight.open(config.dsn) {
        Ok(conn) -> next(SQLiteAdapter(conn))
        Error(_) -> Error("Failed to connect to SQLite data at: " <> config.dsn)
      }
  }
}

fn builtin_driver_from_string(driver: String) -> Option(BuiltinDriver) {
  case string.lowercase(driver) {
    "sqlite" -> Some(SQLite)
    _ -> None
  }
}

fn read_gleam_toml(
  enable_debug: Bool,
  next: fn(String) -> Result(Config(_), String),
) -> Result(Config(_), String) {
  case simplifile.read(from: "./gleam.toml") {
    Ok(content) -> next(content)
    Error(e) -> {
      print_if_debug(enable_debug, e)
      "Unable to read gleam.toml, file either doesn't exist or has permissons-related issues"
      |> Error
    }
  }
}

fn parse_gleam_toml(
  content: String,
  next: fn(MigrantConfig) -> Result(Config(_), String),
) -> Result(Config(_), String) {
  case tom.parse(content) {
    Ok(parsed_content) -> {
      let opt_driver: Option(BuiltinDriver) =
        parsed_content
        |> tom.get_string(["migrant", "driver"])
        |> result.unwrap("sqlite")
        |> builtin_driver_from_string

      use <- bool.guard(
        when: option.is_none(opt_driver),
        return: Error(
          "Invalid driver provided, please see the documentation for all available drivers (in CLI mode) or use the in-code migration method to provide a custom driver/adapter.",
        ),
      )

      let assert Some(driver) = opt_driver

      let dsn: String =
        parsed_content
        |> tom.get_string(["migrant", "dsn"])
        |> result.unwrap("")
        |> string.trim

      use <- bool.guard(
        when: string.is_empty(dsn),
        return: Error("A DSN is required e.g file:data.db"),
      )

      let migrations_path =
        parsed_content
        |> tom.get_string(["migrant", "migrations_path"])
        |> result.unwrap("")
        |> string.trim

      use <- bool.guard(
        when: string.is_empty(migrations_path),
        return: Error(
          "Migrations path is required, this should be the full relative path e.g. /Users/foo/project/priv/migrations",
        ),
      )

      MigrantConfig(driver: driver, migrations_path: migrations_path, dsn: dsn)
      |> next
    }
    Error(tom.Unexpected(got, expected)) ->
      Error(
        "Unexpected input in gleam.toml file, expected "
        <> expected
        <> ", got "
        <> got,
      )
    Error(tom.KeyAlreadyInUse(key)) ->
      Error(
        "Duplicate key encountered in gleam.toml file: "
        <> list.first(key)
        |> result.unwrap("unknown key"),
      )
  }
}

fn print_if_debug(debug_enabled: Bool, e) -> Nil {
  case debug_enabled {
    True -> {
      io.debug(e)
      Nil
    }
    False -> Nil
  }
}
