import evil.{expect}
import glance
import internal/codegen/statements as gens
import internal/codegen/modules as genm
import internal/codegen/types as t
import gleam/string
import gleam/list
import gleam/option.{None, Some}
import gleam/int
import ast.{get_import_path_from_mod_name}
import request.{Request}
import internal/path.{basename}

type StmtGenReq {
  Stmt(t: t.GleamType, module_path: String, imports: List(String))
}

fn request_basic_stmt(t: t.GleamType) {
  Stmt(t, "", [])
}

fn request_stmt(t: t.GleamType, mq, imps) {
  Stmt(t, mq, imps)
}

fn glance_t_to_codegen_t(x: glance.Type, req: request.Request) -> StmtGenReq {
  case x {
    glance.NamedType(name, module, parameters) -> {
      case name {
        "List" -> {
          let assert Ok(t0) = list.at(parameters, 0)
          request_basic_stmt(t.ListType(glance_t_to_codegen_t(t0, req).t))
        }
        "Option" -> {
          // https://serde.rs/enum-representations.html
          let assert Ok(t0) = list.at(parameters, 0)
          request_basic_stmt(t.option(glance_t_to_codegen_t(t0, req).t))
        }
        "Result" -> {
          // https://serde.rs/enum-representations.html
          panic as "Result is unimplemented! serde-style tagging support needed https://serde.rs/enum-representations.html"
        }
        _ -> {
          case module {
            None -> {
              request_basic_stmt(t.AnonymousType(name))
            }
            Some(module_str) -> {
              let type_import_string =
                get_import_path_from_mod_name(module_str, req)
              request_stmt(
                t.AnonymousType(module_str <> "_json"),
                module_str <> "_json.to_json",
                [type_import_string <> "_json"],
              )
            }
          }
        }
      }
    }

    glance.TupleType(elements) ->
      request_basic_stmt(
        t.TupleType(
          list.map(elements, fn(el) { glance_t_to_codegen_t(el, req).t }),
        ),
      )

    glance.FunctionType(_paramters, _return) -> {
      panic as "cannot serialize entities with functions"
    }

    glance.VariableType(_name) -> {
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
      panic as "unimplemented! get_json_serializer_str"
    }
  }
}

fn codegen_t_to_codegen_json_t(gen: StmtGenReq, field_name) {
  let Stmt(gt, module_path, _) = gen
  let json_call_fn_str = get_json_serializer_str(gt)
  let field_name_var = gens.VarPrimitive("t." <> field_name)
  case gt {
    t.AnonymousType(_) -> {
      case module_path {
        "" -> gens.call(json_call_fn_str, [field_name_var])
        mq -> gens.call(mq, [field_name_var])
      }
    }
    t.TupleType(els) -> {
      gens.call(json_call_fn_str, [
        gens.list(
          list.index_map(els, fn(el, i) {
            codegen_t_to_codegen_json_t(
              request_basic_stmt(el),
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
      panic as "unimplemented! codegen_t_to_codegen_json_t"
    }
  }
}

// glance ast -> codegen ast of json serializers
fn serializer_of_t(x: glance.Type, field_name: String, req: request.Request) {
  let gen_req = glance_t_to_codegen_t(x, req)
  #(gen_req, codegen_t_to_codegen_json_t(gen_req, field_name))
}

fn gen_to_json(req) {
  let Request(
    src_module_name: src_module_name,
    type_name: type_name,
    variant: variant,
    ..,
  ) = req
  let #(required_imports, field_serializers) =
    list.fold(variant.fields, #([], []), fn(acc, field) {
      let label =
        option.to_result(field.label, Nil)
        |> expect(
          "Variant " <> variant.name <> " must have labels for all fields",
        )
      let #(gen_req, serializer) = serializer_of_t(field.item, label, req)
      // produce:
      //   foo: my_module.to_json(t.foo)

      #(
        list.concat([acc.0, gen_req.imports]),
        list.concat([
          acc.1,
          [gens.TupleVal([gens.StringVal(label), serializer])],
        ]),
      )
    })

  genm.empty()
  |> genm.add_imports(required_imports)
  |> genm.add_functions([
    gens.Function(
      // string.lowercase(variant.name) <> "_to_json",
      "to_json",
      [
        gens.arg_typed(
          "t",
          t.AnonymousType(basename(src_module_name) <> "." <> type_name),
        ),
      ],
      [gens.call("json.object", [gens.list(field_serializers)])],
    ),
  ])
}

fn gen_to_string(req) {
  let Request(src_module_name: src_module_name, type_name: type_name, ..) = req
  genm.empty()
  |> genm.add_functions([
    gens.Function(
      "to_string",
      [
        gens.arg_typed(
          "t",
          t.AnonymousType(basename(src_module_name) <> "." <> type_name),
        ),
      ],
      [
        gens.call("json.to_string", [gens.call("to_json", [gens.variable("t")])]),
      ],
    ),
  ])
}

pub fn from(req: request.Request) -> String {
  genm.merge(gen_to_json(req), gen_to_string(req))
  |> genm.to_string
}
