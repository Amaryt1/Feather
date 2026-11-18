#include "DirectTLS.h"
#include <stdio.h>
static int save(const char *name, unsigned char *data, size_t length) {
    FILE *f = fopen(name, "wb");
    if (!f) return 0;
    int ok = fwrite(data, 1, length, f) == length;
    return fclose(f) == 0 && ok;
}
int main(void) {
    DirectTLSMaterial m;
    if (!DirectTLSGenerate(&m)) return 1;
    int ok = save("root.der", m.root, m.rootLength) && save("leaf.der", m.leaf, m.leafLength)
          && save("endpoint.pem", m.key, m.keyLength);
    DirectTLSFree(&m);
    return ok ? 0 : 1;
}
