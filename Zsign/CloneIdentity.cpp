#include "CloneIdentity.h"
#include "common.h"
#include "openssl.h"
#include <openssl/x509.h>
#include <memory>

CloneIdentityResult verifyCloneIdentity(const char *keyPath, const char *password, const char *profilePath)
{
    ZSignAsset asset;
    if (!asset.Init("", keyPath, profilePath, "", password, false, false, false))
        return CloneIdentityUnreadable;

    // The pinned Init transfers ownership of these objects to its caller.
    std::unique_ptr<X509, decltype(&X509_free)> leaf(static_cast<X509 *>(asset.m_x509Cert), X509_free);
    std::unique_ptr<EVP_PKEY, decltype(&EVP_PKEY_free)> key(static_cast<EVP_PKEY *>(asset.m_evpPKey), EVP_PKEY_free);
    if (!leaf || !key || X509_check_private_key(leaf.get(), key.get()) != 1)
        return CloneIdentityUnreadable;
    if (X509_cmp_current_time(X509_get0_notBefore(leaf.get())) >= 0 ||
        X509_cmp_current_time(X509_get0_notAfter(leaf.get())) <= 0)
        return CloneIdentityOutsideValidity;

    std::string payload;
    jvalue profile;
    const int length = i2d_X509(leaf.get(), nullptr);
    if (length <= 0 || !ZSignAsset::GetCMSContent(asset.m_strProvData, payload) || !profile.read_plist(payload))
        return CloneIdentityUnreadable;
    std::string der(length, '\0');
    auto buffer = reinterpret_cast<unsigned char *>(&der[0]);
    if (i2d_X509(leaf.get(), &buffer) != length) return CloneIdentityUnreadable;
    const auto &certificates = profile["DeveloperCertificates"];
    for (size_t i = 0; i < certificates.size(); ++i)
        if (certificates[i].as_data() == der) return CloneIdentityValid;
    return CloneIdentityOutsideProfile;
}
