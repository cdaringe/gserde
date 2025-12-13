import gleam/string
import justin

pub fn decoder_name_of_t(raw_name: String) -> String {
  let snake_name = justin.snake_case(raw_name)
  let name = case string.ends_with(snake_name, "_json") {
    True -> string.drop_end(snake_name, 5)
    False -> raw_name
  }
  "get_decoder_" <> name
}
