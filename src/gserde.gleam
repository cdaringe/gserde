import dot_env/env
import evil.{expect}
import fswalk
import glance
import gleam/bool
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import internal/deserializer
import internal/serializer
import request.{type Request, Request}
import simplifile

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

pub fn main() {
  let is_debug = case env.get_bool("DEBUG") {
    Ok(_) -> True
    _ -> False
  }
  fswalk.builder()
  |> fswalk.with_path("src")
  |> fswalk.with_entry_filter(fn(it) {
    string.ends_with(it.filename, ".gleam") && fswalk.only_files(it)
  })
  |> fswalk.walk
  |> fswalk.map(fn(v) { expect(v, "failed to walk").filename })
  |> fswalk.each(fn(f) { process_single(f, is_debug) })
}

pub fn process_single(src_filename: String, is_debug) {
  bool.guard(!is_debug, Nil, fn() {
    io.debug(#("Processing", src_filename))
    Nil
  })

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
    |> list.filter(fn(x) { string.ends_with(x.name, "Json") })

  bool.guard(
    when: list.length(of: custom_types) <= 1,
    return: Nil,
    otherwise: fn() { panic as "Only one json type is allowed per file" },
  )

  let requests =
    custom_types
    |> list.flat_map(fn(custom_type) {
      list.map(custom_type.variants, fn(variant) {
        Request(
          src_module_name: src_module_name,
          type_name: custom_type.name,
          module: parsed,
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
}
