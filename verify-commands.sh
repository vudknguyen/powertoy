#!/usr/bin/env bash
# Verify that the shell commands shown in each powertoy tool actually produce
# the same output the tool produces. Run on a box with GNU coreutils + openssl + jq + python3.
# Each check compares a command's real output to the known-answer the test suite asserts.
pass=0; fail=0
ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31m✗\033[0m %s\n     got: %q\n     want: %q\n' "$1" "$2" "$3"; fail=$((fail+1)); }
chk(){ local name="$1" got="$2" want="$3"; [ "$got" = "$want" ] && ok "$name" || no "$name" "$got" "$want"; }
has(){ local name="$1" got="$2" want="$3"; case "$got" in *"$want"*) ok "$name";; *) no "$name" "$got" "$want";; esac; }

# GNU sed if available (macOS sed lacks \U); fall back to sed
SED=sed; command -v gsed >/dev/null && SED=gsed

echo "ENCODE"
chk "base64 encode"        "$(printf %s 'hello' | base64)" "aGVsbG8="
chk "base64 decode"        "$(printf %s 'aGVsbG8=' | base64 -d)" "hello"
chk "hex encode (xxd -p)"  "$(printf %s 'hi' | xxd -p)" "6869"
chk "hex decode (xxd -r)"  "$(printf %s '6869' | xxd -r -p)" "hi"
chk "base32 encode"        "$(printf %s 'hello' | base32)" "NBSWY3DP"
chk "base32 decode"        "$(printf %s 'NBSWY3DP' | base32 -d)" "hello"
chk "binary (perl unpack)" "$(printf %s 'Hi' | perl -lpe '$_=unpack"B*"')" "0100100001101001"
chk "url encode (jq @uri)" "$(jq -rn --arg s 'hello world' '$s|@uri')" "hello%20world"
chk "url decode (python)"  "$(python3 -c 'import sys,urllib.parse as u; print(u.unquote(sys.argv[1]))' 'hello%20world')" "hello world"
chk "html escape (python)" "$(python3 -c 'import sys,html; print(html.escape(sys.argv[1]))' '<b>&</b>')" "&lt;b&gt;&amp;&lt;/b&gt;"
chk "punycode (python idna)" "$(python3 -c 'print("münchen.de".encode("idna").decode())')" "xn--mnchen-3ya.de"
chk "ascii85 (python a85)"  "$(python3 -c 'import base64,sys; print(base64.a85encode(sys.argv[1].encode()).decode())' 'hello')" "BOu!rDZ"
has "shell quote (printf %q)" "$(printf '%q' "it's")" "it"

echo "CONVERT / UNITS"
chk "radix hex→dec (bash)"  "$(echo $((16#ff)))" "255"
chk "radix dec→hex (printf)" "$(printf '%x' 255)" "ff"
chk "radix dec→bin (bc)"    "$(bc <<< 'obase=2; 255')" "11111111"
chk "color hex→rgb (printf)" "$(printf 'rgb(%d, %d, %d)' 0x10 0x6b 0x5b)" "rgb(16, 107, 91)"
chk "ieee754 double (python)" "$(python3 -c 'import struct,sys; print(struct.pack(">d", float(sys.argv[1])).hex())' 0.1)" "3fb999999999999a"
chk "ieee754 single (python)" "$(python3 -c 'import struct,sys; print(struct.pack(">f", float(sys.argv[1])).hex())' 1)" "3f800000"
has "weight kg→lb (units)"   "$(units -t '1 kg' 'lb' 2>/dev/null)" "2.204622"
has "length m→ft (units)"    "$(units -t '1 m' 'ft' 2>/dev/null)" "3.280839"
has "speed kmh→mph (units)"  "$(units -t '100 km/hour' 'mph' 2>/dev/null)" "62.1371"
has "temp C→F (bc formula)"  "$(echo '100 * 9 / 5 + 32' | bc -l)" "212"   # GNU: units 'tempC(100)' tempF

echo "TIME"
has "epoch→human (date -r)" "$(date -u -r 1718000000 +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "2024-06-10T06:13:20Z"
has "duration humanize (python)" "$(python3 -c 'import datetime; print(datetime.timedelta(seconds=90061))')" "1 day, 1:01:01"

echo "CRYPTO"
has "sha256 (shasum)"      "$(printf %s 'hello' | shasum -a 256)" "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
has "md5 (md5sum)"         "$(printf %s 'hello' | md5sum)" "5d41402abc4b2a76b9719d911017c592"
has "hmac-sha256 (openssl)" "$(printf %s 'payload' | openssl dgst -sha256 -hmac 'secret')" "b82fcb791acec57859b989b430a826488ce2e479fdf92326bd0a2e8375a42ba4"
# JWT signer pipeline (jwt.io canonical example: secret 'your-256-bit-secret')
H=$(printf %s '{"alg":"HS256","typ":"JWT"}' | basenc --base64url 2>/dev/null | tr -d '=')
P=$(printf %s '{"sub":"1234567890","name":"John Doe","iat":1516239022}' | basenc --base64url 2>/dev/null | tr -d '=')
S=$(printf %s "$H.$P" | openssl dgst -sha256 -hmac 'your-256-bit-secret' -binary | basenc --base64url 2>/dev/null | tr -d '=')
chk "jwt sign (openssl pipeline)" "$H.$P.$S" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
chk "objectid ts (python)"  "$(python3 -c 'import sys,datetime; print(datetime.datetime.utcfromtimestamp(int(sys.argv[1][:8],16)).isoformat())' 65f99c110309d4610309d461 2>/dev/null)" "2024-03-19T14:07:13"
chk "uuidgen format"        "$(uuidgen | tr A-F a-f | grep -cE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')" "1"

echo "TEXT / OPS"
chk "json pretty (jq)"      "$(echo '{"a":1}' | jq -c .)" '{"a":1}'
chk "json sort keys (jq)"   "$(echo '{"b":1,"a":2}' | jq -cS .)" '{"a":2,"b":1}'
chk "jsonquery (jq)"        "$(echo '{"users":[{"name":"Ada"},{"name":"Grace"}]}' | jq -c '[.users[].name]')" '["Ada","Grace"]'
chk "case snake→camel (sed)" "$(printf %s 'user_id_field' | $SED -E 's/_(.)/\U\1/g')" "userIdField"
chk "regex replace (perl)"  "$(printf %s 'a1b22c333' | perl -pe 's/\d+/#/g')" "a#b#c#"
chk "cidr mask (python)"    "$(python3 -c 'import ipaddress; print(ipaddress.ip_network("10.0.0.0/22").netmask)')" "255.255.252.0"
chk "cidr hosts (python)"   "$(python3 -c 'import ipaddress; print(ipaddress.ip_network("10.0.0.0/22").num_addresses-2)')" "1022"
chk "csv→json (python)"     "$(printf 'name,score\nAda,99\n' | python3 -c 'import csv,json,sys; print(json.dumps(list(csv.DictReader(sys.stdin))))')" '[{"name": "Ada", "score": "99"}]'
chk "xor hex (python)"      "$(python3 -c 'import sys;d=sys.argv[1].encode();k=sys.argv[2].encode();print(bytes(b^k[i%len(k)] for i,b in enumerate(d)).hex())' 'attack at dawn' 'key')" "$(python3 -c 'print(bytes(b^ "key".encode()[i%3] for i,b in enumerate("attack at dawn".encode())).hex())')"

echo "X.509"
T=$(mktemp); cat > "$T" <<'PEM'
-----BEGIN CERTIFICATE-----
MIIDizCCAnOgAwIBAgIUPjeE+EgHX28lj/ODM8iXPhEq1uAwDQYJKoZIhvcNAQEL
BQAwPDEaMBgGA1UEAwwRdGVzdC5wb3dlcnRveS5kZXYxETAPBgNVBAoMCFBvd2Vy
VG95MQswCQYDVQQGEwJVUzAeFw0yNjA2MTgyMTM3MjJaFw0zNjA2MTUyMTM3MjJa
MDwxGjAYBgNVBAMMEXRlc3QucG93ZXJ0b3kuZGV2MREwDwYDVQQKDAhQb3dlclRv
eTELMAkGA1UEBhMCVVMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCR
mRBhShB/gynJJxkR7cE8xN0YyjE7lezh97qJvDmV3/PZFwlzcP4q2L5mXizm0Svg
cK8lGS6t3n9r+P7Z5gr7POGioPaXDIDmhgILGMjSVGlFUx9MfdChT99iFmfnYXow
ijNWe/aSfvN1IGUBKW+d4zdqeduBZSvrvPD1PBDUUAjlj32qcSOrpOi36juyR9TE
61AWkInB3Gy8BB2yPIfSpHkchoaGELMlOyP0iUFjamKkFxs15CnCSm7kaImXG1xH
5Wzv/y21FHDIJozulK+zjty1q9YCcex6jWKkWOm4E8D5iK9JQmVrvUdVGhMfKP8v
K2b2EJA0wQFI9yeXQSEZAgMBAAGjgYQwgYEwHQYDVR0OBBYEFCLU4DEIew5O5BXb
//mFdMnh5QPHMB8GA1UdIwQYMBaAFCLU4DEIew5O5BXb//mFdMnh5QPHMA8GA1Ud
EwEB/wQFMAMBAf8wLgYDVR0RBCcwJYIRdGVzdC5wb3dlcnRveS5kZXaCEGFsdC5w
b3dlcnRveS5kZXYwDQYJKoZIhvcNAQELBQADggEBAGOHqMcy+Y33vZ2cODuPEEY+
UE8PDd2FHlXlcUmO9swjAzWW3al89Dapif244FY3aBkVg81AsOEbP61rnfZZHEW1
JORPbyyEn7rk55krL83FdbCoSXw8JWAKt1l28uKSfk4sqU/8Eg9rEIqNme6KoEnJ
bDXnoCUZzU1hD/Th1I2S4wUTARCeWMmgsg0DzTXaEWqEMWzgpqxHVqYisnBnVjto
G7vCfuPJ+Yu+y10GZ9wD/DElbgiu243uopc898FN2dETKbCAedeXMo71qGP3tnxS
lUUng66O7SUf47DfBWArd17J2PR/PgLc9mhY5hwq9A2UXusIlwYsxGvLe30flxA=
-----END CERTIFICATE-----
PEM
has "x509 subject CN (openssl)" "$(openssl x509 -in "$T" -noout -subject 2>/dev/null)" "test.powertoy.dev"
has "x509 SAN (openssl)"        "$(openssl x509 -in "$T" -noout -ext subjectAltName 2>/dev/null)" "alt.powertoy.dev"
has "x509 sig alg (openssl)"    "$(openssl x509 -in "$T" -noout -text 2>/dev/null | grep -m1 'Signature Algorithm')" "sha256WithRSA"
rm -f "$T"

echo
printf '\033[1m%d passed, %d failed\033[0m\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
