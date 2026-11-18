#include "DirectTLS.h"
#include <openssl/pem.h>
#include <openssl/x509v3.h>
#include <openssl/rand.h>
#include <string.h>

static int add_extension(X509 *cert, int type, const char *value) {
    X509_EXTENSION *ext = X509V3_EXT_conf_nid(NULL, NULL, type, value);
    int ok = ext && X509_add_ext(cert, ext, -1);
    X509_EXTENSION_free(ext);
    return ok;
}

static X509 *issue(EVP_PKEY *key, X509 *issuer, EVP_PKEY *signer) {
    X509 *cert = X509_new();
    unsigned char serial[16];
    BIGNUM *number = NULL;
    if (!cert || RAND_bytes(serial, sizeof serial) != 1) goto fail;
    number = BN_bin2bn(serial, sizeof serial, NULL);
    if (!number || !BN_to_ASN1_INTEGER(number, X509_get_serialNumber(cert))) goto fail;
    const char *name = issuer ? "AMARYT loopback" : "AMARYT device install root";
    X509_NAME *subject = X509_get_subject_name(cert);
    if (!X509_set_version(cert, 2) || !X509_set_pubkey(cert, key) ||
        !X509_NAME_add_entry_by_txt(subject, "CN", MBSTRING_ASC, (const unsigned char *)name, -1, -1, 0) ||
        !X509_set_issuer_name(cert, issuer ? X509_get_subject_name(issuer) : subject) ||
        !X509_gmtime_adj(X509_getm_notBefore(cert), -300) ||
        !X509_gmtime_adj(X509_getm_notAfter(cert), (issuer ? 180L : 365L) * 86400L) ||
        !add_extension(cert, NID_basic_constraints, issuer ? "critical,CA:FALSE" : "critical,CA:TRUE,pathlen:0") ||
        !add_extension(cert, NID_key_usage, issuer ? "critical,digitalSignature" : "critical,keyCertSign,cRLSign")) goto fail;
    if (issuer && (!add_extension(cert, NID_subject_alt_name, "IP:127.0.0.1") ||
                   !add_extension(cert, NID_ext_key_usage, "serverAuth"))) goto fail;
    if (!X509_sign(cert, signer, EVP_sha256())) goto fail;
    BN_free(number);
    return cert;
fail:
    BN_free(number);
    X509_free(cert);
    return NULL;
}

void DirectTLSFree(DirectTLSMaterial *v) {
    OPENSSL_free(v->root);
    OPENSSL_free(v->leaf);
    OPENSSL_clear_free(v->key, v->keyLength);
    memset(v, 0, sizeof *v);
}

int DirectTLSGenerate(DirectTLSMaterial *out) {
    memset(out, 0, sizeof *out);
    EVP_PKEY *authority = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "prime256v1");
    EVP_PKEY *endpoint = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "prime256v1");
    X509 *root = authority ? issue(authority, NULL, authority) : NULL;
    X509 *leaf = root && endpoint ? issue(endpoint, root, authority) : NULL;
    BIO *bio = BIO_new(BIO_s_mem());
    int ok = 0;
    if (leaf && bio && PEM_write_bio_PrivateKey(bio, endpoint, NULL, NULL, 0, NULL, NULL)) {
        char *pem = NULL;
        long len = BIO_get_mem_data(bio, &pem);
        int r = i2d_X509(root, &out->root), l = i2d_X509(leaf, &out->leaf);
        if (r > 0 && l > 0 && len > 0) {
            out->rootLength = (size_t)r;
            out->leafLength = (size_t)l;
            out->keyLength = (size_t)len;
            out->key = OPENSSL_memdup(pem, out->keyLength);
            ok = out->key != NULL;
            OPENSSL_cleanse(pem, out->keyLength);
        }
    }
    BIO_free(bio); X509_free(root); X509_free(leaf);
    EVP_PKEY_free(authority); EVP_PKEY_free(endpoint);
    if (!ok) DirectTLSFree(out);
    return ok;
}
