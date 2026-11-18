#!/usr/bin/env bash
set -euo pipefail
umask 077
project="$(pwd)"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
cd "$workspace"
cc -Wall -Wextra -Werror -I"$project/Feather/DirectInstall" "$project/Feather/DirectInstall/DirectTLS.c" "$project/Tests/DirectInstall/TLSFixture.c" -o generate -lcrypto
./generate
openssl x509 -inform DER -in root.der -out root.pem
openssl x509 -inform DER -in leaf.der -out leaf.pem
openssl verify -purpose sslserver -verify_ip 127.0.0.1 -CAfile root.pem leaf.pem
if openssl verify -verify_hostname example.org -CAfile root.pem leaf.pem >/dev/null 2>&1; then exit 1; fi
python3 - <<'PY'
import socket, ssl, threading
server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
server.load_cert_chain("leaf.pem", "endpoint.pem")
client = ssl.create_default_context(cafile="root.pem")
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    sock.listen()
    def serve():
        conn, _ = sock.accept()
        with server.wrap_socket(conn, server_side=True) as tls:
            tls.sendall(b"local")
    thread = threading.Thread(target=serve)
    thread.start()
    with socket.create_connection(sock.getsockname(), timeout=5) as conn:
        with client.wrap_socket(conn, server_hostname="127.0.0.1") as tls:
            assert tls.recv(32) == b"local"
    thread.join()
PY
./generate
openssl x509 -inform DER -in root.der -out other.pem
if openssl verify -CAfile other.pem leaf.pem >/dev/null 2>&1; then exit 1; fi
