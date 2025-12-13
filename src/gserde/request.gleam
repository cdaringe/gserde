import glance

pub type Request {
  Request(
    src_module_name: String,
    type_name: String,
    module: glance.Module,
    variant: glance.Variant,
    ser: Bool,
    de: Bool,
  )
}
