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

# lockdownd_connect borrows its provider. Upstream erroneously drops it on an
# error, so the Swift owner would double-free after a refused/closed connection.
p = Path(sys.argv[1]) / "ffi/src/lockdown.rs"
s = p.read_text()
start = s.index('pub unsafe extern "C" fn lockdownd_connect(')
end = s.index('/// Creates a new LockdownClient via RSD', start)
block = s[start:end]
block = block.replace('            let _ = unsafe { Box::from_raw(provider) };\n', '')
p.write_text(s[:start] + block + s[end:])

# Legacy lockdown must authenticate the device as well as the host. Upstream
# skips server-certificate/signature checks to support Apple's unusual names.
# Keep name independence, pin the exact DeviceCertificate from the imported
# trust record, and delegate TLS proof-of-key verification to rustls.
p = Path(sys.argv[1]) / "idevice/src/sni.rs"
s = p.read_text()
if 'MochiLog: pin imported device certificate' not in s:
    s = s.replace('    inner: Arc<WebPkiServerVerifier>,', '    inner: Arc<WebPkiServerVerifier>,\n    device_certificate: CertificateDer<\'static>,', 1)
    s = s.replace('pub fn new(inner: Arc<WebPkiServerVerifier>) -> Self {\n        Self { inner }', 'pub fn new(inner: Arc<WebPkiServerVerifier>, device_certificate: CertificateDer<\'static>) -> Self {\n        Self { inner, device_certificate }', 1)
    s = s.replace('_end_entity: &CertificateDer<\'_>,', 'end_entity: &CertificateDer<\'_>,', 1)
    s = s.replace('        Ok(ServerCertVerified::assertion())', '''        // MochiLog: pin imported device certificate; ignore only its server name.
        if end_entity != &self.device_certificate {
            return Err(rustls::Error::General("device certificate mismatch".into()));
        }
        Ok(ServerCertVerified::assertion())''', 1)
    for version in ('12', '13'):
        start = s.index(f'    fn verify_tls{version}_signature(')
        end = s.index('\n    }', start) + 6
        block = s[start:end].replace('_message', 'message').replace('_cert', 'cert').replace('_dss', 'dss')
        block = block.replace('Ok(HandshakeSignatureValid::assertion())', f'self.inner.verify_tls{version}_signature(message, cert, dss)')
        s = s[:start] + block + s[end:]
    s = s.replace('NoServerNameVerification::new(inner)', 'NoServerNameVerification::new(inner, pairing_file.device_certificate.clone())', 1)
    assert 'device certificate mismatch' in s
    p.write_text(s)
