import gleam/list.{map}
import gleam/string.{join}

pub type GleamType {
  AnonymousType(String)
  NilType
  IntType
  TupleType(elements: List(GleamType))
  ListType(list_type: GleamType)
  VariantType(name: String, variants: List(Variant))
  VariantDepType(
    name: String,
    dep_types: List(GleamType),
    variants: List(Variant),
  )
  FunctionType(argument_types: List(GleamType), result_type: GleamType)
}

pub type Variant {
  Variant(name: String, fields: List(Field))
}

pub type Field {
  Field(name: String, field_type: GleamType)
}

pub fn nil() -> GleamType {
  NilType
}

pub fn int() -> GleamType {
  IntType
}

pub fn variant_type(name: String, variants: List(Variant)) -> GleamType {
  VariantType(name, variants)
}

pub fn variant(name: String, fields: List(Field)) -> Variant {
  Variant(name, fields)
}

pub fn field(name: String, field_type: GleamType) -> Field {
  Field(name, field_type)
}

pub fn option(some_type: GleamType) -> GleamType {
  VariantDepType("Option", [some_type], [
    variant("Some", [field("some", some_type)]),
    variant("Error", []),
  ])
}

pub fn result(ok_type: GleamType, error_type: GleamType) -> GleamType {
  VariantDepType("Result", [ok_type, error_type], [
    variant("Ok", [field("ok", ok_type)]),
    variant("Error", [field("error", error_type)]),
  ])
}

pub fn function(
  argument_types: List(GleamType),
  result_type: GleamType,
) -> GleamType {
  FunctionType(argument_types, result_type)
}

// maybe this is a root-statement, and thus should move to another file?
pub fn generate_type_def(gleam_type: GleamType) -> String {
  case gleam_type {
    AnonymousType(name) -> name
    NilType -> ""
    IntType -> ""
    ListType(list_type) -> "List(" <> generate_type_def(list_type) <> ")"
    TupleType(elements) ->
      "#("
      <> list.map(elements, generate_type_def)
      |> join(", ")
      <> ")"
    VariantDepType(name, dep_types, variants) ->
      "pub type "
      <> name
      <> "("
      <> dep_types
      |> map(generate_type_def)
      |> join(", ")
      <> ") {\n"
      <> variants
      |> map(generate_variant)
      |> join("\n")
      <> "\n}"
    VariantType(name, variants) ->
      "pub type "
      <> name
      <> " {\n"
      <> variants
      |> map(generate_variant)
      |> join("\n")
      <> "\n}"
    FunctionType(argument_types, result_type) ->
      "fn("
      <> argument_types
      |> map(generate_type)
      |> join(", ")
      <> ") -> "
      <> generate_type(result_type)
  }
}

fn generate_variant(variant: Variant) -> String {
  "  "
  <> variant.name
  <> "("
  <> variant.fields
  |> map(generate_field)
  |> join(", ")
  <> ")"
}

fn generate_field(field: Field) -> String {
  field.name <> ": " <> generate_type(field.field_type)
}

pub fn generate_type(arg_type: GleamType) {
  case arg_type {
    AnonymousType(name) -> name
    NilType -> "Nil"
    IntType -> "Int"
    ListType(list_type) -> "List(" <> generate_type_def(list_type) <> ")"
    VariantDepType(name, dep_types, _variants) ->
      name
      <> "("
      <> dep_types
      |> map(generate_type)
      |> join(", ")
      <> ")"
    TupleType(els) -> generate_type_def(TupleType(els))
    VariantType(name, _variants) -> name
    FunctionType(args, result) ->
      "fn("
      <> args
      |> map(generate_type)
      |> join(", ")
      <> ") -> "
      <> generate_type(result)
  }
}
