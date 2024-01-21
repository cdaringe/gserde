import glance
import internal/codegen/statements as gens
import internal/codegen/types as t
import gleam/string
import gleam/list
import gleam/option
import gleam/io
import gleam/int
import request.{type Request, Request}
import internal/path.{basename}

fn quote(str) {
  "\"" <> str <> "\""
}

fn gen_decoder(typ) {
  case typ {
    glance.NamedType(name, _module_todo, parameters) -> {
      case name {
        "List" -> {
          let assert Ok(t0) = list.at(parameters, 0)
          gens.call("dynamic.list", [gen_decoder(t0)])
        }
        "Option" -> {
          let assert Ok(t0) = list.at(parameters, 0)
          gens.call("dynamic.optional", [gen_decoder(t0)])
        }
        _ -> gens.VarPrimitive("dynamic." <> string.lowercase(name))
      }
    }
    glance.TupleType(parts) -> {
      let m_tuple =
        list.length(of: parts)
        |> int.to_string
      gens.call(
        "dynamic.tuple" <> string.lowercase(m_tuple),
        parts
        |> list.map(gen_decoder),
      )
    }
    x -> {
      io.debug(#("warning: unsupported decoding", x))
      gens.VarPrimitive("dynamic.toodoo")
    }
  }
}

fn gen_root_decoder(req) {
  let Request(
    src_module_name: src_module_name,
    type_name: _type_name,
    variant: variant,
    ..,
  ) = req
  let n_str =
    list.length(of: variant.fields)
    |> int.to_string
  gens.Function(
    "from_json",
    [gens.arg_typed("json_str", t.AnonymousType("String"))],
    [
      gens.call("json.decode", [
        gens.VarPrimitive("json_str"),
        gens.call("dynamic.decode" <> n_str, [
          gens.VarPrimitive( basename(src_module_name) <> "." <> variant.name),
          ..list.map(req.variant.fields, fn(field) {
            gens.call("dynamic.field", [
              gens.VarPrimitive(
                option.lazy_unwrap(field.label, fn() {
                  panic as "@todo/panic variants must be labeled"
                })
                |> quote,
              ),
              gen_decoder(field.item),
            ])
          })
        ]),
      ]),
    ],
  )
}

pub fn to(req: Request) {
  [gen_root_decoder(req)]
  |> list.map(gens.generate)
  |> string.join(with: "\n")
}
