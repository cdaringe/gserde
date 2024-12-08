import gleam/io
import gleam/list

pub fn at(l: List(a), index: Int) {
  list.index_map(l, fn(x, i) { #(x, i) })
  |> list.find_map(fn(x: #(a, Int)) {
    case x.1 {
      v if v == index -> Ok(x.0)
      _ -> Error(Nil)
    }
  })
}

pub fn expect(x, msg) {
  case x {
    Ok(v) -> v
    Error(_) -> {
      io.print_error(msg)
      panic
    }
  }
}
