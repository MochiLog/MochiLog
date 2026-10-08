# Plist FFI

[idevice](https://github.com/jkcoxson/idevice) has an FFI C interface.
The FFI library used to convert between libplist and Rust's plist crate
by serializing to XML and deserializing on the other side of the FFI boundary.

This adds complication and a large performance overhead. To bridge the gap,
I've taken libplist's headers and designed a compatible Rust library under it.

TLDR: libplist has been ported to Rust using the plist crate.

## Testing

The tests that make sense in this context have been copied over from libplist.
They pass with the exception of deserialization disrepencies with spaces.

## C++

The C++ source and headers have been copied over, making this library usable
from C++. Tests that make sense to run complete with the same caveats as above.

## Design

The plist library is designed as nodes. Pointers to a wrapping struct are passed
as libplist's ``plist_t``. Each wrapper maintains a vector of child nodes that
are created by various libplist methods, and frees them when the parent is freed.

Wrappers are allocated with pointers to the child node they reference, and then
are freed with the parent.

## Issues

The plist crate has serde issues with the UID type. There is an open issue from
years ago with no progress being made towards fixing it.

## License

I'm not a lawyer. libplist's code (header, C++, tests) are under their original
license. Any code written by me (Rust files) are under MIT OR libplist's license. 
Please open an issue if this licensing is illegal or incompatible.
