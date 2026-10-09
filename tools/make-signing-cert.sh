#!/bin/bash
# One-time: create a local code-signing certificate so macOS keeps the Accessibility
# grant across rebuilds (ad-hoc signatures change on every build and lose it).
# Run this yourself; it asks for your login password once to trust the certificate.
set -euo pipefail
NAME="Speed Editor Bridge Dev"
if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "Identity '$NAME' already exists."; exit 0
fi
TMP=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -subj "/CN=$NAME" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"
openssl pkcs12 -export -macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -out "$TMP/id.p12" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout pass:seb -name "$NAME"
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P seb -T /usr/bin/codesign -T /usr/bin/security
# Trust it for code signing (user domain). macOS prompts for your login password here.
security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem"
rm -rf "$TMP"
security find-identity -v -p codesigning | grep "$NAME" && echo "Done. Rebuild with ./make-app.sh and grant Accessibility once more."
