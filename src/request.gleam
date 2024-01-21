import glance

pub type Request {
  Request(
    src_module_name: String,
    type_name: String,
    variant: glance.Variant,
    ser: Bool,
    de: Bool,
  )
}
