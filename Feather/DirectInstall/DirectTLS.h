#ifndef AMARYT_DIRECT_TLS_H
#define AMARYT_DIRECT_TLS_H
#include <stddef.h>
typedef struct {
    unsigned char *root, *leaf, *key;
    size_t rootLength, leafLength, keyLength;
} DirectTLSMaterial;
int DirectTLSGenerate(DirectTLSMaterial *out);
void DirectTLSFree(DirectTLSMaterial *value);
#endif
