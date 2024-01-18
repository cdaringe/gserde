import gleam/io
import gleam/list
import gleam/string
import glance
import serializer
import simplifile

// type Foo = Int
pub type Request {
  Request(variant: glance.Variant, ser: Bool, de: Bool, outfile: String)
}

type BarJSON {
  Bar(Bool, #(Int))
  Baz(Int)
}

pub fn gen(req: Request) {
  io.debug(req.variant)
  case req.ser {
    True -> Ok(serializer.from(req.variant))
    _ -> Error(Nil)
  }
  Nil
}

pub fn main() {
  let assert Ok(code) = simplifile.read(from: "src/gserde.gleam")
  let assert Ok(parsed) = glance.module(code)
  let custom_types =
    list.map(parsed.custom_types, fn(def) { def.definition })
    |> list.filter(fn(x) { string.ends_with(x.name, "JSON") })
  let requests =
    custom_types
    |> list.flat_map(fn(custom_type) {
      list.map(custom_type.variants, fn(variant) {
        Request(variant, ser: True, de: False, outfile: "foo.gleam")
      })
    })

  list.map(requests, gen)

  Nil
}
