# plist_macro

Macros and utilities to make ``plist`` manipulation easy

## General overview/usage

```rust
use plist_macro::{plist, pretty_print_plist};

let hmmm = Some(true);

let flatten_me = plist!({
    "a": 1,
    "b": 2,
})

let value = plist!({
    "code": 200,
    "success": true,
    "payload": {
        "features": [
            "serde",
            "plist"
        ],
        "homepage": null
    },
    "optional":? hmmm,
    :< flatten_me
});

println!("{:?}", pretty_print_plist(&value));
```

Force into a dictionary

```rust
use plist_macro::{plist, pretty_print_dictionary};

let value = plist!(dict { // <- this makes a dictionary, not a generic value
    "wow": true,
});

println!("{:?}", pretty_print_dictionary(&value));
```

Generic plist values

```rust
use plist_macro::{plist};

let value = plist!(1);
let value2 = plist!(true);
let value3 = plist!("hi mom");
```

Go crazy

## License

MIT
