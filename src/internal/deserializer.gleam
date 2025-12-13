import common.{decoder_name_of_t}
import glance
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import internal/codegen/statements as gens
import internal/codegen/types as t
import internal/path.{basename}
import request.{type Request, Request}

fn quote(str) {
  "\"" <> str <> "\""
}

fn gen_decoder(typ) {
  case typ {
    glance.NamedType(_location, name, module, parameters) -> {
      case name {
        "List" -> {
          let assert Ok(t0) = list.first(parameters)
          gens.call("decode.list", [gen_decoder(t0)])
        }
        "Option" -> {
          let assert Ok(t0) = list.first(parameters)
          gens.call("decode.optional", [gen_decoder(t0)])
        }
        _ -> {
          case module {
            option.None -> {
              gens.VarPrimitive("decode." <> string.lowercase(name))
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
    glance.TupleType(_location, elements) -> {
      gens.Block(
        list.flatten([
          elements
            |> list.index_map(fn(element, i) {
              gens.UseExpr(
                "el" <> int.to_string(i),
                gens.call("decode.field", [gens.IntVal(i), gen_decoder(element)]),
              )
            }),

          [
            gens.call("decode.success", [
              gens.TupleVal(
                elements
                |> list.index_map(fn(_element, i) {
                  gens.VarPrimitive("el" <> int.to_string(i))
                }),
              ),
            ]),
          ],
        ]),
      )
    }
    x -> {
      io.println_error(string.inspect(#("warning: unsupported decoding", x)))
      gens.Direct("todo")
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

  let decoder_fn_name = decoder_name_of_t(type_name)

  [
    gens.Function(
      decoder_fn_name,
      [],
      list.flatten([
        list.map(req.variant.fields, fn(field) {
          case field {
            glance.LabelledVariantField(_, label) -> {
              gens.UseExpr(
                label,
                gens.call("decode.field", [
                  gens.VarPrimitive(quote(label)),
                  gen_decoder(field.item),
                ]),
              )
            }
            glance.UnlabelledVariantField(_) ->
              panic as "variants must be labelled"
          }
        }),
        [
          gens.call("decode.success", [
            gens.call(
              basename(src_module_name) <> "." <> variant.name,
              list.map(req.variant.fields, fn(field) {
                case field {
                  glance.LabelledVariantField(_, label) ->
                    gens.VarPrimitive(label)
                  glance.UnlabelledVariantField(_) ->
                    panic as "variants must be labelled"
                }
              }),
            ),
          ]),
        ],
      ]),
    ),
    gens.Function(
      "from_string",
      [gens.arg_typed("json_str", t.AnonymousType("String"))],
      [
        gens.call("json.parse", [
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
