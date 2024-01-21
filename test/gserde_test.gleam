import gleeunit
import gleeunit/should
import simplifile
import gleam/string
import gleam/list
import shellout

pub fn main() {
  gleeunit.main()
}

const foo_module = "import gleam/option.{type Option}
pub type FooJSON {
  Foo(
    a_bool: Bool,
    b_int: Int,
    c_float: Float,
    d_two_tuple: #(Int, String),
    e_option_int: Option(Int),
    f_string_list: List(String),
  )
}
"

const foo_json_test = "
import gleam/option.{Some}
import gleam/io
import gleam/result
import internal/foo
import internal/foo_json

pub fn main() {
  let foo_a = foo.Foo(
    a_bool: True,
    b_int: 1,
    c_float: 1.0,
    d_two_tuple: #(2, \"3\"),
    e_option_int: Some(4),
    f_string_list: [\"a\", \"b\"]
  )

  let foo_str = foo_a
    |> foo_json.to_string

  let foo_b = foo_str |> foo_json.from_json |> result.lazy_unwrap(fn() {
    io.debug(\"parse error calling foo_json.from_json\")
    panic
  })

  case foo_a == foo_b {
    True -> io.println(\"foos equal\")
    False -> {
      io.debug(#(\"a\", foo_a))
      io.debug(#(\"b\", foo_b))
      panic as \"not equal\"
    }
  }

  io.print(foo_str)
}
"

fn exec(bin: String, args: List(String)) {
  let assert Ok(output) =
    shellout.command(bin, args, in: ".", opt: [shellout.LetBeStderr])
  output
}

//
/// This test is thorough, but a bit zany. We:
/// - write a dummy "foo" module into the current project's source. hopefully it compiles!
/// - run our CLI against the project, which should produce a serde module next to foo
/// - write an entrypoint module--foo_json_test--into our source, then run it!
pub fn end_to_end_test() {
  // create the foo fixture
  let assert Ok(_) =
    simplifile.write(to: "src/internal/foo.gleam", contents: foo_module)

  // run our gen cli
  exec("gleam", ["run"])

  // write our test module and run it
  let assert Ok(_) =
    simplifile.write(
      to: "src/internal/foo_json_test.gleam",
      contents: foo_json_test,
    )
  let assert Ok(last_output_line) =
    exec("gleam", ["run", "-m=internal/foo_json_test"])
    |> string.split("\n")
    |> list.last

  last_output_line
  |> should.equal(
    "{\"a_bool\":true,\"b_int\":1,\"c_float\":1.0,\"d_two_tuple\":[2,\"3\"],\"e_option_int\":4,\"f_string_list\":[\"a\",\"b\"]}",
  )
}
