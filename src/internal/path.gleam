import gleam/string
import gleam/list
import gleam/result

pub fn basename(path: String) {
  string.split(path, on: "/")
  |> list.last
  |> result.unwrap(or: "")
}
