# Migrant

Database migrations for SQLite in Gleam

## Usage

```gleam
import gleam/erlang
import app/database
import migrant

pub fn main() {
  let db = database.connect()

  let assert Ok(priv_directory) = erlang.priv_directory("app")
  let assert Ok(_) = migrant.migrate(db, priv_directory <> "/migrations")

  Nil
}
```

## Installation

This library is currently being developed as it is used in projects & as needed, there are no stable (or really any) releases yet and there won't be for a while.
If you want to use it regardless, you can install it as a local dependency by cloning this repo and adding this to your `gleam.toml` file

> UPDATE: there is an alpha release now (for convenience), use at your own risk

```toml
[dependencies]
migrant = { path = "path/to/migrant" }
```

### Installing Alpha from Hex

Again, this has not been thoroughly tested, it has been built to suit what I need at the moment, use at your own risk.

```sh
gleam add migrant
```

## Targets

In theory, this should work in both Javascript and Erlang targets since all the dependencies have support for both targets, but it is only currently being developed and tested against the Erlang/BEAM runtime.
