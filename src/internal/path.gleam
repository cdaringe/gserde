import gleam/list
import gleam/result
import gleam/string

pub fn basename(path: String) {
  string.split(path, on: "/")
  |> list.last
  |> result.unwrap(or: "")
}
