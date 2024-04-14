import glance
import internal/codegen/statements as gens
import internal/codegen/types as t
import gleam/string
import gleam/list
import gleam/option
import gleam/io
import gleam/int
import request.{type Request, Request}
import common.{decoder_name_of_t}
import internal/path.{basename}
import evil.{expect}

fn quote(str) {
  "\"" <> str <> "\""
}

fn gen_decoder(typ, req: Request) {
  case typ {
    glance.NamedType(name, module_name, parameters) -> {
      case name {
        "List" -> {
          let assert Ok(t0) = list.at(parameters, 0)
          gens.call("dynamic.list", [gen_decoder(t0, req)])
        }
        "Option" -> {
          let assert Ok(t0) = list.at(parameters, 0)
          gens.call("dynamic.optional", [gen_decoder(t0, req)])
        }
        _ -> {
          case module_name {
            option.None -> {
              gens.VarPrimitive("dynamic." <> string.lowercase(name))
            }
            option.Some(module_str) -> {
              gens.VarPrimitive(
                module_str <> "_json." <> decoder_name_of_t(name) <> "()",
              )
            }
          }
        }
      }
    }
    glance.TupleType(parts) -> {
      let m_tuple =
        list.length(of: parts)
        |> int.to_string
      gens.call(
        "dynamic.tuple" <> string.lowercase(m_tuple),
        parts
          |> list.map(fn(part) { gen_decoder(part, req) }),
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
    type_name: type_name,
    variant: variant,
    ..,
  ) = req
  let n_str =
    list.length(of: variant.fields)
    |> int.to_string

  let decoder_fn_name = decoder_name_of_t(type_name)

  [
    gens.Function(decoder_fn_name, [], [
      gens.call("dynamic.decode" <> n_str, [
        gens.VarPrimitive(basename(src_module_name) <> "." <> variant.name),
        ..list.map(req.variant.fields, fn(field) {
          gens.call("dynamic.field", [
            gens.VarPrimitive(
              option.to_result(field.label, Nil)
              |> expect("@todo/panic variants must be labeled")
              |> quote,
            ),
            gen_decoder(field.item, req),
          ])
        })
      ]),
    ]),
    gens.Function(
      "from_string",
      [gens.arg_typed("json_str", t.AnonymousType("String"))],
      [
        gens.call("json.decode", [
          gens.VarPrimitive("json_str"),
          gens.call(decoder_fn_name, []),
        ]),
      ],
    ),
  ]
}

pub fn to(req: Request) {
  gen_root_decoder(req)
  |> list.map(gens.generate)
  |> string.join(with: "\n")
}
