# Migrant

Database migrations for SQLite in Gleam

## Installation

This library is currently being developed as it is used in projects & as needed, there are no stable (or really any) releases yet and there won't be for a while.
If you want to use it regardless, you can install it as a local dependency by cloning this repo and adding this to your `gleam.toml` file

```toml
[dependencies]
migrant = { path = "path/to/migrant" }
```

## Targets

In theory, this should work in both Javascript and Erlang targets since all the dependencies have support for both targets, but it is only currently being developed and tested against the Erlang/BEAM runtime.
