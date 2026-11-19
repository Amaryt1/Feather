#include "../../Zsign/CloneIdentity.h"
#include <cstdlib>

int main(int argc, char **argv) {
    if (argc != 5) return 1;
    return verifyCloneIdentity(argv[1], argv[2], argv[3]) == std::atoi(argv[4]) ? 0 : 1;
}
