import gleeunit
import gleeunit/should
import gleam/option.{Some}
import foo
import foo_json

pub fn main() {
  gleeunit.main()
}

pub fn serialize_test() {
  let input = foo.Foo(
    a_bool: True,
    b_int: 1,
    c_float: 1.0,
    d_one_tuple: #(1),
    e_two_tuple: #(2, "3"),
    f_option_int: Some(4),
    g_string_list: ["a", "b"]
  )

  input
  |> foo_json.to_string
  |> should.equal(
    "{\"a_bool\":true,\"b_int\":1,\"c_float\":1,\"d_one_tuple\":[1],\"e_two_tuple\":[2,\"3\"],\"f_option_int\":4,\"g_string_list\":[\"a\",\"b\"]}",
  )
}
