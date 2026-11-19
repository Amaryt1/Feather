#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CloneIdentityValid,
    CloneIdentityUnreadable,
    CloneIdentityOutsideProfile,
    CloneIdentityOutsideValidity
} CloneIdentityResult;

CloneIdentityResult verifyCloneIdentity(const char *keyPath, const char *password, const char *profilePath);

#ifdef __cplusplus
}
#endif
