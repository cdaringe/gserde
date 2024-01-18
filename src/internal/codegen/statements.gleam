import gleam/int.{to_string as to_s}
import gleam/option.{type Option, None, Some}
import gleam/list.{map}
import gleam/string.{join}
import internal/codegen/types.{type GleamType} as t

/// Direct is a string that will be in the generated code, verbatim.
pub type GleamStatement {
  NilVal
  IntVal(value: Int)
  ListVal(items: List(GleamStatement))
  StringVal(string: String)
  TupleVal(items: List(GleamStatement))
  VariantVal(name: String, fields: List(GleamStatement))
  VarPrimitive(name: String)
  Comparison(GleamStatement, ComparisonOperator, GleamStatement)
  CaseStatement(guards: List(GleamStatement), clauses: List(Clause))
  Function(
    name: String,
    arguments: List(Argument),
    statements: List(GleamStatement),
  )
  FunctionCall(name: String, arguments: List(GleamStatement))
  UseArg(arg: GleamStatement)

  LetVar(pattern: Pattern, statement: GleamStatement)
  LetArray(patterns: List(Pattern), array: GleamStatement)
  LetTuple(patterns: List(Pattern), tuple: GleamStatement)

  Multiply(terms: List(GleamStatement))

  Direct(string: String)
}

pub type ComparisonOperator {
  Lt
  Lte
  Eq
  Neq
  Gt
  Gte
}

pub opaque type Clause {
  Clause(patterns: List(Pattern), stmt: GleamStatement)
}

pub opaque type Pattern {
  Anything(name: Option(String))
  ConstantPattern(String)
  Variable(String)
}

pub opaque type Argument {
  Argument(name: String, arg_type: GleamType)
}

pub fn nil() {
  NilVal
}

pub fn ok(value: GleamStatement) {
  VariantVal("Ok", [value])
}

pub fn error(error: GleamStatement) {
  VariantVal("Error", [error])
}

pub fn int(value: Int) {
  IntVal(value)
}

pub fn list(values: List(GleamStatement)) -> GleamStatement {
  ListVal(values)
}

pub fn variant(name, field_values: List(GleamStatement)) -> GleamStatement {
  VariantVal(name, field_values)
}

pub fn variable(name: String) -> GleamStatement {
  VarPrimitive(name)
}

pub fn compare(
  stmt1: GleamStatement,
  comp_op: ComparisonOperator,
  stmt2: GleamStatement,
) {
  Comparison(stmt1, comp_op, stmt2)
}

pub fn case_stmt(
  guards: List(GleamStatement),
  clauses: List(Clause),
) -> GleamStatement {
  CaseStatement(guards, clauses)
}

pub fn clause(patterns: List(Pattern), stmt: GleamStatement) {
  Clause(patterns, stmt)
}

pub fn underscore() {
  Anything(None)
}

/// name: variable name without the underscore, it will be prepended when generating code
pub fn unused_var(name: String) {
  Anything(Some(name))
}

/// a constant patter, such as `True` or `42` (represented as a string, for now)
pub fn literal(lit: String) {
  ConstantPattern(lit)
}

pub fn var_pattern(var: String) -> Pattern {
  Variable(var)
}

// TODO add return type
// if we provide a full function type, we have that; only missing fn&arg names?
pub fn function(
  name: String,
  arguments: List(Argument),
  statements: List(GleamStatement),
) {
  Function(name, arguments, statements)
}

pub fn arg(name: String, arg_type: GleamType) {
  Argument(name, arg_type)
}

pub fn call(name: String, arguments: List(GleamStatement)) {
  FunctionCall(
    name,
    arguments
    |> map(UseArg),
  )
}

pub fn use_arg(arg: Argument) {
  VarPrimitive(arg.name)
}

pub fn name_of_var(var: GleamStatement) {
  let assert VarPrimitive(name) = var
  name
}

pub fn let_var(pattern: Pattern, statement: GleamStatement) -> GleamStatement {
  LetVar(pattern, statement)
}

/// TODO: Needs middle argument `Option(Pattern)` for `..tail`
pub fn let_array(
  patterns: List(Pattern),
  array: GleamStatement,
) -> GleamStatement {
  LetArray(patterns, array)
}

pub fn let_tuple(
  patterns: List(Pattern),
  tuple: GleamStatement,
) -> GleamStatement {
  LetTuple(patterns, tuple)
}

pub fn multiply(terms: List(GleamStatement)) -> GleamStatement {
  Multiply(terms)
}

/// @deprecated
pub fn direct(string) {
  Direct(string)
}

pub fn generate(stmt: GleamStatement) -> String {
  case stmt {
    NilVal -> "Nil"
    IntVal(value) -> to_s(value)
    ListVal(items) ->
      "["
      <> items
      |> map(generate)
      |> join(", ")
      <> "]"
    StringVal(s) -> "\"" <> s <> "\""
    TupleVal(items) ->
      "#("
      <> items
      |> map(generate)
      |> join(", ")
      <> ")"
    VariantVal(name, []) -> name
    VariantVal(name, fields) ->
      name
      <> "("
      <> fields
      |> map(generate)
      |> join(", ")
      <> ")"
    VarPrimitive(name) -> name
    Comparison(stmt1, op, stmt2) ->
      generate(stmt1)
      <> " "
      <> generate_comparison(op)
      <> " "
      <> generate(stmt2)
    CaseStatement(guards, clauses) ->
      "case "
      <> guards
      |> map(generate)
      |> join(", ")
      <> " {\n"
      <> {
        clauses
        |> map(generate_clause)
        |> join("\n")
      }
      <> "\n}"
    Function(name, args, statements) ->
      "pub fn "
      <> name
      <> "("
      <> args
      |> map(generate_arg)
      |> join(", ")
      <> ") {\n"
      <> statements
      |> map(generate)
      |> join("\n")
      <> "\n}\n"
    FunctionCall(name, arguments) -> {
      name
      <> "("
      <> arguments
      |> map(generate)
      |> join(", ")
      <> ")"
    }
    UseArg(arg) -> generate(arg)

    LetVar(pattern, statement) ->
      "let " <> generate_pattern(pattern) <> " = " <> generate(statement)

    LetArray(patterns, array) ->
      "let ["
      <> patterns
      |> map(generate_pattern)
      |> join(", ")
      <> "] = "
      <> generate(array)

    LetTuple(patterns, array) ->
      "let #("
      <> patterns
      |> map(generate_pattern)
      |> join(", ")
      <> ") = "
      <> generate(array)

    Multiply(terms) ->
      terms
      |> map(generate)
      |> join(" * ")

    Direct(string) -> string
  }
}

fn generate_comparison(op: ComparisonOperator) {
  case op {
    Lt -> "<"
    Lte -> "<="
    Eq -> "=="
    Neq -> "!="
    Gt -> ">"
    Gte -> ">="
  }
}

fn generate_clause(clause: Clause) {
  "  "
  <> clause.patterns
  |> map(generate_pattern)
  |> join(", ")
  <> " -> "
  <> generate(clause.stmt)
}

fn generate_pattern(pattern: Pattern) {
  case pattern {
    Anything(None) -> "_"
    Anything(Some(name)) -> "_" <> name
    ConstantPattern(constant) -> constant
    Variable(name) -> name
  }
}

fn generate_arg(arg: Argument) {
  arg.name <> ": " <> t.generate_type(arg.arg_type)
}
