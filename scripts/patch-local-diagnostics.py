"""Minimal FFI entry point for upstream pair-verify, never automatic pair-setup."""
from pathlib import Path
import sys
p = Path(sys.argv[1]) / "ffi/src/tunnel_provider.rs"
s = p.read_text()
if 'fn mochilog_tunnel_verify_rppairing(' in s:
    start = end = -1
else:
    start = s.index('#[unsafe(no_mangle)]\npub unsafe extern "C" fn tunnel_create_rppairing(')
    end = s.index('\n/// Pairs with a device', start)
    original = s[start:end]
    verified = original.replace('fn tunnel_create_rppairing(', 'fn mochilog_tunnel_verify_rppairing(', 1)
    old = 'rpc.connect(rpf, async || get_pin(pin_callback, &ctx))\n            .await?;'
    assert old in verified
    verified = verified.replace(old, 'rpc.attempt_pair_verify().await?;\n        rpc.validate_pairing(rpf).await?;', 1)
    p.write_text(s[:end] + '\n// MochiLog: authenticated existing credential only; no PIN/setup fallback.\n' + verified + s[end:])
# crash_report_client_ls allocates count+1 pointers with Rust's allocator,
# but the upstream advertised AFC destructor is not exported. Free in Rust.
p = Path(sys.argv[1]) / "ffi/src/crashreportcopymobile.rs"
s = p.read_text()
if 'fn mochilog_crash_entries_free(' not in s:
    s += '''
/// Frees exactly the array returned by crash_report_client_ls.
/// Safety: entries/count must come from that function, once only.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mochilog_crash_entries_free(entries: *mut *mut c_char, count: usize) {
    if entries.is_null() { return; }
    for i in 0..count {
        let pointer = unsafe { *entries.add(i) };
        if !pointer.is_null() { let _ = unsafe { std::ffi::CString::from_raw(pointer) }; }
    }
    let layout = std::alloc::Layout::array::<*mut c_char>(count + 1).unwrap();
    unsafe { std::alloc::dealloc(entries as *mut u8, layout) };
}
'''
p.write_text(s)
