# gserde

**warning**: alpha quality package with poor code hygiene, including assert/panic/todo
statements.

[![Package Version](https://img.shields.io/hexpm/v/gserde)](https://hex.pm/packages/gserde)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gserde/)

```sh
gleam add gserde
```

## usage

1. Create custom type with a singular variant constructor. See the example
   `src/foo.gleam` below.
2. Run `gleam run -m gserde`.
3. Observe the generated file `src/foo_json.gleam`.
4. Use the new `foo_json` module!

```gleam
// src/foo.gleam
import gleam/option.{type Option}
pub type FooJson {
  Foo(
    a_bool: Bool,
    b_int: Int,
    c_float: Float,
    d_two_tuple: #(Int, String),
    e_option_int: Option(Int),
    f_string_list: List(String),
  )
}

// src/foo_json.gleam
// generated!
import gleam/json
import gleam/dynamic
import internal/foo

pub fn to_json(t: foo.FooJson) {
  json.object([
    #("a_bool", json.bool(t.a_bool)),
    #("b_int", json.int(t.b_int)),
    #("c_float", json.float(t.c_float)),
    #(
      "d_two_tuple",
      json.preprocessed_array([
        json.int(t.d_two_tuple.0),
        json.string(t.d_two_tuple.1),
      ]),
    ),
    #("e_option_int", json.nullable(t.e_option_int, json.int)),
    #("f_string_list", json.array(t.f_string_list, json.string)),
  ])
}

pub fn to_string(t: foo.FooJson) {
  json.to_string(to_json(t))
}

pub fn get_decoder_foo() {
  dynamic.decode6(
    foo.Foo,
    dynamic.field("a_bool", dynamic.bool),
    dynamic.field("b_int", dynamic.int),
    dynamic.field("c_float", dynamic.float),
    dynamic.field("d_two_tuple", dynamic.tuple2(dynamic.int, dynamic.string)),
    dynamic.field("e_option_int", dynamic.optional(dynamic.int)),
    dynamic.field("f_string_list", dynamic.list(dynamic.string)),
  )
}

pub fn from_string(json_str: String) {
  json.decode(json_str, get_decoder_foo())
}

// src/my_module.gleam
import foo
import foo_json

pub fn serialization_identity_test() {
  let foo_1 = foo.Foo(..) // make a Foo

  let foo_2 = foo_1
    |> foo_json.to_string // 👀, stringify the Foo to JSON!
    |> foo_json.from_string // 👀, parse the Foo from JSON!

  foo_1 == foo_2 // pass the identity test
}
```

You can set `DEBUG=1` to get verbose output during codegen.

## todo

- [ ] complete all cases
- [ ] remove all invocations of assert/panic/todo
- [x] support non-gleam primitive types
- [ ] handle all module references properly

Further documentation can be found at <https://hexdocs.pm/gserde>.

## Development

```sh
gleam test  # Run the tests
```
