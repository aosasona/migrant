import gleam/dynamic/decode
import gleam/erlang
import gleam/result
import gleeunit
import gleeunit/should
import migrant
import simplifile
import sqlight

const migration_name = "0001_create_test_table"

const sample_up = "
  CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);
  INSERT INTO test (id, name) VALUES (1, 'test');
  "

const sample_bad_up = "
  CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);
  INSERT INTO test (id, name) VALUES (1, 'test', 4);
"

const sample_down = "DROP TABLE test;"

type MigrationType {
  Good
  Bad
}

pub fn main() {
  gleeunit.main()
}

pub fn migration_test() {
  setup(Good)
  let db =
    sqlight.open(db_path())
    |> should.be_ok

  migrant.migrate(db, migration_path())
  |> should.be_ok

  // Check that the migration was applied
  let query =
    "SELECT name FROM sqlite_master WHERE type='table' AND name='test';"

  sqlight.query(query, db, [], decode.at([0], decode.string))
  |> should.be_ok

  let query = "SELECT id, name FROM test;"
  let test_decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    decode.success(#(id, name))
  }

  // Check that the data was inserted correctly
  sqlight.query(query, db, [], test_decoder)
  |> should.be_ok
  |> should.equal([#(1, "test")])

  cleanup()
}

pub fn bad_migration_test() {
  setup(Bad)
  let db =
    sqlight.open(db_path())
    |> should.be_ok

  migrant.migrate(db, migration_path())
  |> should.be_error

  // Check that the migration was not applied
  let query =
    "SELECT name FROM sqlite_master WHERE type='table' AND name='test';"
  let decoder = decode.at([0], decode.string)
  let result =
    sqlight.query(query, db, [], decoder)
    |> result.map_error(fn(_) { Nil })
    |> result.map(fn(rows) {
      case rows {
        [] -> Nil
        _ -> panic as "^^ Migration was applied when it shouldn't have been ^^"
      }
    })
  result
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

fn setup(t: MigrationType) -> Nil {
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

  let _ = case t {
    Good -> write_good_migrations()
    Bad -> write_bad_migrations()
  }

  Nil
}

fn write_good_migrations() {
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
}

fn write_bad_migrations() {
  // Create a sample migration
  let _ =
    simplifile.write(
      to: migration_path() <> "/" <> migration_name <> ".up.sql",
      contents: sample_bad_up,
    )
}

fn cleanup() {
  let _ =
    simplifile.delete(priv_dir())
    |> result.map_error(fn(_) { Nil })
}
