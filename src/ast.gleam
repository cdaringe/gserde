import evil.{expect}
import gleam/list
import gleam/string
import request.{type Request}

pub fn get_import_path_from_mod_name(module_str: String, req: Request) {
  list.find_map(in: req.module.imports, with: fn(imp) {
    let full_module_str = imp.definition.module
    case
      full_module_str == module_str
      || string.ends_with(full_module_str, "/" <> module_str)
    {
      True -> Ok(full_module_str)
      _ -> Error(Nil)
    }
  })
  |> expect(module_str <> ": module not found in import list")
}
