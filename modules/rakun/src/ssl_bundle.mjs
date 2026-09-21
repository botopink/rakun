// rakun — the SSL bundle registry, node half: the twin of
// `src/sidecars/rakun_ssl.erl`.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so the
// registry — a two-level `name` → `field` → value table, in registration order —
// lives in the host. Beside it are the two pieces of X.509 reading that are not
// string work: the certificate's fields (`crypto.X509Certificate`) and the
// certificate/key correspondence check (`X509Certificate#checkPrivateKey`).
//
// WHAT DOES *NOT* LIVE HERE. The property grammar, the defaults, the posture
// mapping (`client-auth` → verify/fail_if_no_peer_cert, `verify` → verify/
// hostname), the option-list encoding, the JKS refusal, the reload rule and
// every refusal message are botopink, in `src/ssl_bundle.bp`, compiled to both
// targets. This file holds a Map, a certificate reader and two joins.
//
// WHY A NODE HALF AT ALL, GIVEN THAT THE FRONT IS ERLANG-ONLY. `ssl:listen/2` is
// erlang-only and nothing here calls it: the listener OPTIONS are an encoded
// blob, and encoding is the same string on both rows. What forces this file to
// exist is the measured shape that `botopink test` compiles every `test/*.bp` on
// BOTH rows with no per-target gate, so a cell with only an `#[@External.Erlang]`
// form reddens the commonJS row at its call site — and `modules/rakun`'s pinned
// row is commonJS. The erlang-only work (turning the blob into a real option
// list, and generating self-test material) is in the sidecar as plain erlang
// functions that no `.bp` cell names.
//
// THE RENDERING CONTRACT. `certInfo` answers the milestone's blob. `subject` and
// `issuer` are canonicalised to `CN=…,O=…` in certificate order: node answers
// newline-separated attributes and OTP answers an `rdnSequence` of OID tuples,
// and one assertion has to be able to name one string. The instants are
// `YYYY-MM-DDTHH:MM:SSZ`. `daysRemaining` is floored, so a certificate with
// twelve hours left reads `0` and one that expired an hour ago reads `-1`.

import { X509Certificate, createPrivateKey } from "node:crypto";

// name -> Map(field -> value); insertion order is registration order, which is
// what `names()` promises and what a Map gives for free.
const bundles = new Map();

function slot(name) {
  let m = bundles.get(name);
  if (m === undefined) {
    m = new Map();
    bundles.set(name, m);
  }
  return m;
}

export function put(name, field, value) {
  slot(name).set(field, value);
  return 0;
}

export function get(name, field) {
  const m = bundles.get(name);
  if (m === undefined) return "";
  const v = m.get(field);
  return v === undefined ? "" : v;
}

export function names() {
  return Array.from(bundles.keys()).join("\n");
}

export function forget(name) {
  bundles.delete(name);
  return 0;
}

export function reset() {
  bundles.clear();
  return 0;
}

// ── the certificate reader ───────────────────────────────────────────────────

function iso(d) {
  if (!d) return "";
  return d.toISOString().slice(0, 19) + "Z";
}

// Node renders an RDN as newline-separated `TYPE=value`, in certificate order.
// The canonical form is the same attributes joined with a comma.
function rdn(text) {
  if (!text) return "";
  return String(text)
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join(",");
}

export function certInfo(pem) {
  let cert;
  try {
    cert = new X509Certificate(pem);
  } catch (err) {
    return "error|" + String((err && err.message) || err).replace(/[;|]/g, " ");
  }
  const notAfter = cert.validToDate;
  const days =
    notAfter === undefined || notAfter === null
      ? 0
      : Math.floor((notAfter.getTime() - Date.now()) / 86400000);
  return [
    "subject|" + rdn(cert.subject),
    "issuer|" + rdn(cert.issuer),
    "notBefore|" + iso(cert.validFromDate),
    "notAfter|" + iso(notAfter),
    "daysRemaining|" + String(days),
  ].join(";");
}

// A certificate with no key is not a mismatch — a verify-only bundle has none,
// and `ssl_bundle.bp` never calls this for one. An unreadable key IS a mismatch:
// rakun will not present material it could not load.
export function keyMatches(certPem, keyPem) {
  if (!certPem || !keyPem) return false;
  try {
    const cert = new X509Certificate(certPem);
    return cert.checkPrivateKey(createPrivateKey(keyPem));
  } catch (_err) {
    return false;
  }
}

// ── the five consumer seams ──────────────────────────────────────────────────

export function listenerOpts(bundle) {
  return get(bundle, "listener");
}

// SNI is the caller's hostname and the bundle is not, so it is appended here
// rather than stored. `verify_hostname` already said whether it is checked.
export function clientOpts(bundle, host) {
  const base = get(bundle, "client");
  if (base === "") return "";
  return base + ";server_name_indication|" + host;
}

export function expiryDays(bundle) {
  const raw = get(bundle, "days");
  const n = parseInt(raw, 10);
  return Number.isNaN(n) ? 0 : n;
}

export function subject(bundle) {
  return get(bundle, "subject");
}

export function lastError(bundle) {
  return get(bundle, "error");
}
