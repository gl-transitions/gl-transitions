// The catalog and shader files in generated/ come from the npm package build and are not
// committed: say how to get them instead of failing on a missing include!.
fn main() {
    println!("cargo:rerun-if-changed=generated/catalog.rs");
    if !std::path::Path::new("generated/catalog.rs").exists() {
        panic!(
            "crates/gl-transitions/generated/ is missing: run `pnpm run build && pnpm run build:crate` \
             at the root of the gl-transitions repository"
        );
    }
}
