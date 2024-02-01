# gserde

**warning**: alpha package with poor code hygiene, including assert/panic/todo
statements. Use understanding that this package is not ready for primetime.

[![Package Version](https://img.shields.io/hexpm/v/gserde)](https://hex.pm/packages/gserde)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gserde/)

```sh
gleam add gserde
```

## usage

1. Create custom type with a singular variant constructor:
2. Run `gleam run -m gserde`
3. Observe `src/foo_json.gleam`, which has the goodies you need for json (de)serialization.

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

// src/my_module.gleam
import foo
import foo_json

pub fn serialization_identity_test() {
  let foo_1 = foo.Foo(..)

  let foo_2 = foo_1
    |> foo_json.to_string // 👀
    |> foo_json.from_string // 👀

  foo_1 == foo_2
}
```

## todo

- [ ] complete all cases
- [ ] remove all invocations of assert/panic/todo
- [ ] support non-gleam primitive types
- [ ] handle all module references properly

Further documentation can be found at <https://hexdocs.pm/gserde>.

## Development

```sh
gleam test  # Run the tests
```
