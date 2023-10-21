import gleam/io
import gleam/dynamic
import gleam/map
import gleam/list
import gleam/string
import gleam/int
import gleam/result
import gleam/option.{None, Some}
import migrant/types.{
  DatabaseError, Error, Migration, MigrationError, Migrations, RollbackError,
}
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
  io.println("-> Creating migrations table")

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
  io.println("-> Filtering applied migrations")
  let sql = "SELECT name FROM __migrations ORDER BY id, name ASC;"

  case query(db, sql, [], dynamic.element(0, dynamic.string)) {
    Ok(applied) ->
      migrations
      |> map.drop(drop: applied)
      |> fn(m: Migrations) {
        let count = map.size(m)
        case count {
          0 -> {
            io.println("-> No migrations to apply")
            Ok(Nil)
          }
          _ -> {
            io.println(
              "-> Found " <> int.to_string(map.size(m)) <> " " <> pluralise_migration(
                count,
              ) <> " to apply",
            )
            next(m)
          }
        }
      }
    Error(e) -> {
      io.debug(e)
      io.println("-> Failed to filter applied migrations")
      Error(e)
    }
  }
}

fn pluralise_migration(count: Int) -> String {
  case count {
    1 -> "migration"
    _ -> "migrations"
  }
}

pub fn apply_migrations(
  db: sqlight.Connection,
  migrations: Migrations,
) -> Result(Nil, Error) {
  io.println("-> Applying migrations")

  // sort migrations by name to ensure they are applied in order - we need to use a list here
  let count =
    migrations
    |> sort_migrations
    |> run_migration(db, 0)

  case count {
    Ok(count) -> {
      io.println("-> Applied " <> int.to_string(count) <> " migrations")
      Ok(Nil)
    }
    Error(e) -> Error(e)
  }

  Ok(Nil)
}

fn run_migration(
  migrations: List(#(String, Migration)),
  db: sqlight.Connection,
  count: Int,
) -> Result(Int, Error) {
  case migrations {
    [] -> Ok(count)
    [migration, ..rest] -> {
      case apply(migration, db) {
        Ok(_) -> run_migration(rest, db, count + 1)
        Error(e) -> Error(e)
      }
    }
  }
}

fn apply(migration_tuple: #(String, Migration), db: sqlight.Connection) {
  let #(name, migration) = migration_tuple
  case migration.up {
    Some(sql) -> {
      io.println("-> Applying migration: " <> name)
      case exec(db, sql) {
        Ok(_) -> {
          case mark_migration_as_applied(db, migration_tuple) {
            Ok(_) -> Ok(Nil)
            Error(e) -> {
              io.println("-> Rolling back migration: " <> name)
              case rollback(migration_tuple, db) {
                Ok(_) ->
                  Error(MigrationError(
                    "Rollback complete, failed to mark migration as applied: " <> name,
                    e,
                  ))
                Error(e) -> Error(e)
              }
            }
          }
          Ok(Nil)
        }
        Error(e) -> {
          io.println("-> Rolling back migration: " <> name)
          case rollback(migration_tuple, db) {
            Ok(_) ->
              Error(MigrationError(
                "Rollback complete, failed to apply migration: " <> name,
                e,
              ))
            Error(e) -> Error(e)
          }
        }
      }
    }
    None -> {
      io.println("-> Skipping migration: " <> name <> " no `up` query")
      Ok(Nil)
    }
  }
}

fn rollback(migration_tuple: #(String, Migration), db: sqlight.Connection) {
  let #(name, migration) = migration_tuple
  case migration.down {
    Some(sql) -> {
      case exec(db, sql) {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(e)
      }
    }
    None -> {
      Error(MigrationError(
        "Unable to rollback migration: " <> name,
        RollbackError,
      ))
    }
  }
}

fn mark_migration_as_applied(
  db: sqlight.Connection,
  migration_tuple: #(String, Migration),
) -> Result(Nil, Error) {
  let #(name, _) = migration_tuple
  let sql = "INSERT INTO __migrations (name) VALUES (?) returning id;"

  case query(db, sql, [sqlight.text(name)], dynamic.element(0, dynamic.int)) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(e)
  }
}

fn sort_migrations(migrations: Migrations) -> List(#(String, Migration)) {
  migrations
  |> map.to_list
  |> list.sort(fn(a, b) {
    let #(name_a, _) = a
    let #(name_b, _) = b
    string.compare(name_a, name_b)
  })
}
