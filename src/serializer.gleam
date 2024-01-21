import glance
import internal/codegen/statements as gens
import internal/codegen/types as t
import gleam/string
import gleam/list
import gleam/option
import gleam/io
import gleam/int
import request.{Request}
import internal/path.{basename}

fn glance_t_to_codegen_t(x: glance.Type) -> t.GleamType {
  case x {
    glance.NamedType(name, _module, parameters) -> {
      // @todo resolve types from modules
      // io.debug(#("glance_t_to_codegen_t", name))
      case name {
        "List" -> {
          let assert Ok(t0) = list.at(parameters, 0)
          t.ListType(glance_t_to_codegen_t(t0))
        }
        "Option" -> {
          // @todo options are untagged, and just `null | T`
          // https://serde.rs/enum-representations.html
          let assert Ok(t0) = list.at(parameters, 0)
          t.option(glance_t_to_codegen_t(t0))
        }
        "Result" -> {
          // @todo options are untagged, and just `null | T`
          // https://serde.rs/enum-representations.html
          panic as "Result is unimplemented! serde-style tagging support needed https://serde.rs/enum-representations.html"
        }
        _ -> t.AnonymousType(name)
      }
    }

    glance.TupleType(elements) ->
      t.TupleType(list.map(elements, glance_t_to_codegen_t))

    glance.FunctionType(_paramters, _return) -> {
      panic as "cannot serialize entities with functions"
    }

    glance.VariableType(_name) -> {
      // io.debug(name)
      panic as "unimplemented! VariableType"
    }
  }
}

pub fn get_json_serializer_str(ct: t.GleamType) {
  case ct {
    t.AnonymousType(name) -> "json." <> string.lowercase(name)
    t.TupleType(_) -> {
      "json.preprocessed_array"
    }
    t.ListType(_) -> "json.array"
    t.VariantDepType(name, _, _) -> {
      case name {
        "Option" -> {
          "json.nullable"
        }
        _ -> {
          panic as "VariantDefType not supported: " <> name
        }
      }
    }
    _ -> {
      // io.debug(#("codegen type failed: ", ct))
      todo
    }
  }
}

fn codegen_t_to_codegen_json_t(ct, field_name) {
  // io.debug(#("codegen type: ", ct))
  let json_call_fn_str = get_json_serializer_str(ct)
  let field_name_var = gens.VarPrimitive("t." <> field_name)
  case ct {
    t.AnonymousType(_) -> gens.call(json_call_fn_str, [field_name_var])
    t.TupleType(els) -> {
      gens.call(json_call_fn_str, [
        gens.list(
          list.index_map(els, fn(el, i) {
            codegen_t_to_codegen_json_t(
              el,
              field_name <> "." <> int.to_string(i),
            )
          }),
        ),
      ])
    }
    t.ListType(inner) -> {
      gens.call(json_call_fn_str, [
        field_name_var,
        gens.VarPrimitive(get_json_serializer_str(inner)),
      ])
    }
    t.VariantDepType(_name, dep_types, _variants) -> {
      gens.call(json_call_fn_str, [
        field_name_var,
        ..list.map(dep_types, fn(inner) {
          gens.VarPrimitive(get_json_serializer_str(inner))
        })
      ])
    }
    _ -> {
      // io.debug(#("codegen_t_to_codegen_json_t failed: ", ct))
      todo
    }
  }
}

// glance ast -> codegen ast of json serializers
fn serializer_of_t(x: glance.Type, field_name: String) {
  let ct = glance_t_to_codegen_t(x)
  codegen_t_to_codegen_json_t(ct, field_name)
}

fn gen_to_json(req) {
  let Request(
    src_module_name: src_module_name,
    type_name: type_name,
    variant: variant,
    ..,
  ) = req
  gens.Function(
    // string.lowercase(variant.name) <> "_to_json",
    "to_json",
    [gens.arg_typed("t", t.AnonymousType(basename(src_module_name) <> "." <> type_name))],
    [
      gens.call("json.object", [
        gens.list(
          list.map(variant.fields, fn(field) {
            case option.to_result(field.label, Nil) {
              Ok(label) -> {
                // io.debug(#(field))
                gens.TupleVal([
                  gens.StringVal(label),
                  serializer_of_t(field.item, label),
                ])
              }
              _ -> {
                io.println_error(
                  "Variant "
                    <> variant.name
                    <> " must have labels for all fields",
                )
                panic as "missing label"
              }
            }
          }),
        ),
      ]),
    ],
  )
}

fn gen_to_string(req) {
  let Request(src_module_name: src_module_name, type_name: type_name, ..) = req
  gens.Function(
    "to_string",
    [gens.arg_typed("t", t.AnonymousType(basename(src_module_name) <> "." <> type_name))],
    [gens.call("json.to_string", [gens.call("to_json", [gens.variable("t")])])],
  )
}

pub fn from(req: request.Request) {
  [gen_to_json(req), gen_to_string(req)]
  |> list.map(gens.generate)
  |> string.join(with: "\n")
}
