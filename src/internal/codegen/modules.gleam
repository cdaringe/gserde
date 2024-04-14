import gleam/list
import gleam/string
import gleam/set
import internal/codegen/types.{type GleamType} as t
import internal/codegen/statements.{type GleamStatement} as gens

pub type Mod {
  Mod(
    name: String,
    functions: List(GleamStatement),
    types: List(GleamType),
    imports: List(String),
  )
}

pub fn empty() -> Mod {
  Mod(name: "", functions: [], types: [], imports: [])
}

pub fn add_functions(mod: Mod, functions: List(GleamStatement)) -> Mod {
  Mod(..mod, functions: list.concat([mod.functions, functions]))
}

pub fn add_imports(mod: Mod, imports: List(String)) -> Mod {
  Mod(..mod, imports: list.concat([mod.imports, imports]))
}

pub fn merge(m1: Mod, m2: Mod) {
  Mod(
    name: m1.name,
    functions: list.concat([m1.functions, m2.functions]),
    types: list.concat([m1.types, m2.types]),
    imports: list.concat([m1.imports, m2.imports])
      |> set.from_list
      |> set.to_list,
  )
}

pub fn to_string(m: Mod) {
  list.concat([
    list.map(m.imports, fn(i) { "import " <> i }),
    list.map(m.types, t.generate_type_def),
    list.map(m.functions, gens.generate),
  ])
  |> string.join("\n")
}
