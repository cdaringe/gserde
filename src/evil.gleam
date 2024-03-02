import gleam/io

pub fn expect(x, msg) {
  case x {
    Ok(v) -> v
    Error(_) -> {
      io.print_error(msg)
      panic
    }
  }
}
