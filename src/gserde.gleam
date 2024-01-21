import gleam/io
import gleam/list
import gleam/bool
import gleam/string
import gleam/result
import glance
import serializer
import deserializer
import simplifile
import request.{type Request, Request}
import fswalk

pub fn gen(req: Request) {
  let ser =
    bool.guard(when: req.ser, return: serializer.from(req), otherwise: fn() {
      ""
    })
  let de =
    bool.guard(when: req.de, return: deserializer.to(req), otherwise: fn() {
      ""
    })

  #(
    req,
    [ser, de]
    |> string.join("\n\n"),
  )
}

fn to_output_filename(src_filename) {
  string.replace(in: src_filename, each: ".gleam", with: "_json.gleam")
}

fn expect(x, msg) {
  case x {
    Ok(v) -> v
    Error(_) -> {
      io.print_error(msg)
      panic
    }
  }
}

pub fn main() {
  fswalk.builder()
  |> fswalk.with_path("src")
  |> fswalk.with_entry_filter(fswalk.only_files)
  |> fswalk.walk
  |> fswalk.map(fn(v) { expect(v, "failed to walk").filename })
  |> fswalk.each(process_single)
}

pub fn process_single(src_filename: String) {
  io.debug(#(src_filename))
  // let assert Ok(gleam_toml_str) = simplifile.read(from: "gleam.toml")
  // let assert Ok(gleam_toml) = tom.parse(gleam_toml_str)
  // let assert Ok(pkg_name) = tom.get_string(gleam_toml, ["name"])
  let src_module_name =
    src_filename
    |> string.replace("src/", "")
    |> string.replace(".gleam", "")
  let dest_filename = to_output_filename(src_filename)

  let assert Ok(code) = simplifile.read(from: src_filename)

  let assert Ok(parsed) =
    glance.module(code)
    |> result.map_error(fn(err) {
      io.debug(err)
      panic
    })

  let custom_types =
    list.map(parsed.custom_types, fn(def) { def.definition })
    |> list.filter(fn(x) { string.ends_with(x.name, "JSON") })
  let requests =
    custom_types
    |> list.flat_map(fn(custom_type) {
      list.map(custom_type.variants, fn(variant) {
        Request(
          src_module_name: src_module_name,
          type_name: custom_type.name,
          variant: variant,
          ser: True,
          de: True,
        )
      })
    })

  let filecontent =
    list.map(requests, gen)
    |> list.map(fn(it) { it.1 })
    |> string.join("\n\n")

  case filecontent {
    "" -> Nil
    _ ->
      simplifile.write(
        to: dest_filename,
        contents: [
          "import gleam/json",
          "import gleam/dynamic",
          "import " <> src_module_name,
          filecontent,
        ]
        |> string.join("\n"),
      )
      |> result.unwrap(Nil)
  }
  // foo.Foo(a: True, b: #(123))
  // |> foo_json.to_string
  // |> io.println
}
