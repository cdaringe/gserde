import glance
import internal/codegen/statements as gens
import internal/codegen/types as t
import gleam/json.{array, int, null, object, string}
import gleam/string
import gleam/list
import gleam/option
import gleam/io

// pub fn cat_to_json(cat: Cat) -> String {
//   object([
//     #("name", string(cat.name)),
//     #("lives", int(cat.lives)),
//     #("flaws", null()),
//     #("nicknames", array(cat.nicknames, of: string)),
//   ])
//   |> json.to_string
// }

fn glance_t_to_codegen_t(x: glance.Type) -> t.GleamType {
  case x {
    glance.NamedType(name, module, parameters) -> {
      // uhhhh how will we resolve types from modules
      t.AnonymousType(name)
    }
    glance.TupleType(elements) -> {
      // t.ListType(elements, glance_t_to_codegen_t)
      todo
    }
    glance.FunctionType(paramters, return) -> {
      panic as "cannot serialize entities with functions"
    }
    glance.VariableType(name) -> {
      io.debug(name)
      panic as "unimplemented! VariableType"
    }
  }
}

// glance ast -> codegen ast of json serializers
fn serializer_of_t(x: glance.Type) {
  let ct = glance_t_to_codegen_t(x)
  case ct {
    t.AnonymousType(name) -> gens.call("json." <> string.lowercase(name), [])
    _ -> todo
  }
}

pub fn from(variant: glance.Variant) {
  gens.Function(
    string.lowercase(variant.name) <> "_to_json",
    [gens.arg("t", t.AnonymousType(variant.name))],
    [gens.call(
      "json.object",
      list.map(variant.fields, fn(field) {
        let assert Ok(label) = option.to_result(field.label, Nil)
        // @todo produce a tuple here not just the value
        // #(label, serializer_of_t(field.item))
        serializer_of_t(field.item)
      })
    )],
  )
}
