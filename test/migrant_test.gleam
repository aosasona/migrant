import gleam/erlang
import gleam/result
import gleeunit
import gleeunit/should
import migrant
import simplifile
import sqlight

const migration_name = "0001_create_test_table"

const sample_up = "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);"

const sample_down = "DROP TABLE test;"

pub fn main() {
  gleeunit.main()
}

pub fn migration_test() {
  setup()
  let db =
    sqlight.open(db_path())
    |> should.be_ok

  migrant.migrate(db, migration_path())
  |> should.be_ok

  cleanup()
}

fn priv_dir() -> String {
  case erlang.priv_directory("migrant") {
    Ok(dir) -> dir
    Error(e) -> {
      echo e
      panic as "^^ Failed to get priv directory ^^"
    }
  }
}

fn migration_path() -> String {
  priv_dir() <> "/migrations"
}

fn db_path() -> String {
  priv_dir() <> "/test.db"
}

fn setup() -> Nil {
  // Create the priv directory if it doesn't exist
  let _ = simplifile.create_directory(priv_dir())

  // Create the db file if it doesn't exist
  let is_file = case simplifile.is_file(db_path()) {
    Ok(is_file) -> is_file
    Error(e) -> {
      echo e
      panic as "^^ Failed to check for existence of db file ^^"
    }
  }

  let _ = case is_file {
    True -> simplifile.create_file(db_path())
    False -> Ok(Nil)
  }

  // Create the migrations folder
  let _ = simplifile.create_directory(migration_path())

  // Create a sample migration
  let _ =
    simplifile.write(
      to: migration_path() <> "/" <> migration_name <> ".up.sql",
      contents: sample_up,
    )

  let _ =
    simplifile.write(
      to: migration_path() <> "/" <> migration_name <> ".down.sql",
      contents: sample_down,
    )

  Nil
}

fn cleanup() {
  let _ =
    simplifile.delete(priv_dir())
    |> result.map_error(fn(_) { Nil })
}
