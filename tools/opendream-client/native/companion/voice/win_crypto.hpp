#pragma once
// Windows CNG (bcrypt.dll) helpers for region voice: the game poll ID, the
// bot token ID and opening the bot's sealed token. Mirrors
// Civilizationbot src/Civ13/VoiceLobbies.php:
//   poll id  = hex(sha1("civ13-voice-state:" + key))
//   token id = hex(sha256("civ13-voice-token:" + key))
//   seal key = HKDF-SHA256(ikm = key, salt = none, info = "civ13-voice-seal", 32)
//   sealed   = base64(nonce[12] | ciphertext | tag[16]), AES-256-GCM, AAD = token id
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <bcrypt.h>

#include <optional>
#include <string>
#include <string_view>
#include <vector>

#ifdef _MSC_VER
#pragma comment(lib, "bcrypt.lib")
#endif

namespace civ13::voice::crypto {

#ifndef NT_SUCCESS
#define NT_SUCCESS(status) (((NTSTATUS)(status)) >= 0)
#endif

class Algorithm {
public:
  Algorithm(LPCWSTR id, ULONG flags) {
    if (!NT_SUCCESS(BCryptOpenAlgorithmProvider(&handle, id, nullptr, flags)))
      handle = nullptr;
  }
  ~Algorithm() {
    if (handle) BCryptCloseAlgorithmProvider(handle, 0);
  }
  Algorithm(const Algorithm &) = delete;
  Algorithm &operator=(const Algorithm &) = delete;
  BCRYPT_ALG_HANDLE handle = nullptr;
};

inline std::optional<std::string> digest(LPCWSTR id, std::string_view key,
                                         std::string_view data, std::size_t size) {
  Algorithm alg(id, key.empty() ? 0 : BCRYPT_ALG_HANDLE_HMAC_FLAG);
  if (!alg.handle) return std::nullopt;
  BCRYPT_HASH_HANDLE hash = nullptr;
  if (!NT_SUCCESS(BCryptCreateHash(alg.handle, &hash, nullptr, 0,
                                   reinterpret_cast<PUCHAR>(const_cast<char *>(key.data())),
                                   static_cast<ULONG>(key.size()), 0)))
    return std::nullopt;
  std::string out(size, '\0');
  const bool ok =
      NT_SUCCESS(BCryptHashData(hash, reinterpret_cast<PUCHAR>(const_cast<char *>(data.data())),
                                static_cast<ULONG>(data.size()), 0)) &&
      NT_SUCCESS(BCryptFinishHash(hash, reinterpret_cast<PUCHAR>(out.data()),
                                  static_cast<ULONG>(out.size()), 0));
  BCryptDestroyHash(hash);
  if (!ok) return std::nullopt;
  return out;
}

inline std::string hex(std::string_view bytes) {
  static const char digits[] = "0123456789abcdef";
  std::string out;
  for (char ch : bytes) {
    const auto c = static_cast<unsigned char>(ch);
    out.push_back(digits[c >> 4]);
    out.push_back(digits[c & 15]);
  }
  return out;
}

inline std::optional<std::string> sha1_hex(std::string_view data) {
  auto d = digest(BCRYPT_SHA1_ALGORITHM, {}, data, 20);
  return d ? std::optional<std::string>(hex(*d)) : std::nullopt;
}

inline std::optional<std::string> sha256_hex(std::string_view data) {
  auto d = digest(BCRYPT_SHA256_ALGORITHM, {}, data, 32);
  return d ? std::optional<std::string>(hex(*d)) : std::nullopt;
}

inline std::optional<std::string> hmac_sha256(std::string_view key, std::string_view data) {
  // CNG rejects an empty HMAC key, and RFC 5869's default salt is 32 zero bytes anyway.
  const std::string zero(32, '\0');
  return digest(BCRYPT_SHA256_ALGORITHM, key.empty() ? std::string_view(zero) : key, data, 32);
}

// RFC 5869 with no salt, as PHP's hash_hkdf('sha256', ikm, length, info).
inline std::optional<std::string> hkdf_sha256(std::string_view ikm, std::string_view info,
                                              std::size_t length) {
  auto prk = hmac_sha256({}, ikm);
  if (!prk || length > 255 * 32) return std::nullopt;
  std::string out, block;
  for (unsigned char counter = 1; out.size() < length; ++counter) {
    std::string input = block;
    input.append(info);
    input.push_back(static_cast<char>(counter));
    auto next = hmac_sha256(*prk, input);
    if (!next) return std::nullopt;
    block = *next;
    out.append(block);
  }
  out.resize(length);
  return out;
}

inline std::optional<std::string> aes_256_gcm_open(std::string_view key, std::string_view nonce,
                                                   std::string_view ciphertext, std::string_view tag,
                                                   std::string_view aad) {
  if (key.size() != 32 || nonce.size() != 12 || tag.size() != 16) return std::nullopt;
  Algorithm alg(BCRYPT_AES_ALGORITHM, 0);
  if (!alg.handle) return std::nullopt;
  const wchar_t mode[] = BCRYPT_CHAIN_MODE_GCM;
  if (!NT_SUCCESS(BCryptSetProperty(alg.handle, BCRYPT_CHAINING_MODE,
                                    reinterpret_cast<PUCHAR>(const_cast<wchar_t *>(mode)),
                                    sizeof(mode), 0)))
    return std::nullopt;
  BCRYPT_KEY_HANDLE handle = nullptr;
  if (!NT_SUCCESS(BCryptGenerateSymmetricKey(alg.handle, &handle, nullptr, 0,
                                             reinterpret_cast<PUCHAR>(const_cast<char *>(key.data())),
                                             static_cast<ULONG>(key.size()), 0)))
    return std::nullopt;
  std::string nonce_copy(nonce), tag_copy(tag), aad_copy(aad);
  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO info;
  BCRYPT_INIT_AUTH_MODE_INFO(info);
  info.pbNonce = reinterpret_cast<PUCHAR>(nonce_copy.data());
  info.cbNonce = static_cast<ULONG>(nonce_copy.size());
  info.pbTag = reinterpret_cast<PUCHAR>(tag_copy.data());
  info.cbTag = static_cast<ULONG>(tag_copy.size());
  info.pbAuthData = reinterpret_cast<PUCHAR>(aad_copy.data());
  info.cbAuthData = static_cast<ULONG>(aad_copy.size());
  std::string input(ciphertext);
  std::string out(input.size(), '\0');
  ULONG written = 0;
  const NTSTATUS status = BCryptDecrypt(
      handle, reinterpret_cast<PUCHAR>(input.data()), static_cast<ULONG>(input.size()), &info,
      nullptr, 0, reinterpret_cast<PUCHAR>(out.data()), static_cast<ULONG>(out.size()), &written, 0);
  BCryptDestroyKey(handle);
  if (!NT_SUCCESS(status)) return std::nullopt;
  out.resize(written);
  return out;
}

inline std::optional<std::string> poll_id(std::string_view key) {
  return sha1_hex(std::string("civ13-voice-state:").append(key));
}

inline std::optional<std::string> token_id(std::string_view key) {
  return sha256_hex(std::string("civ13-voice-token:").append(key));
}

// The bot's sealed token, opened. Null when it does not open (wrong key,
// tampered, truncated).
inline std::optional<std::string> open_sealed(std::string_view key, std::string_view id,
                                              std::string_view raw) {
  if (raw.size() < 28) return std::nullopt;
  auto seal_key = hkdf_sha256(key, "civ13-voice-seal", 32);
  if (!seal_key) return std::nullopt;
  return aes_256_gcm_open(*seal_key, raw.substr(0, 12), raw.substr(12, raw.size() - 28),
                          raw.substr(raw.size() - 16), id);
}

// Random bytes from the system generator.
inline std::optional<std::string> random_bytes(std::size_t size) {
  std::string out(size, '\0');
  if (!NT_SUCCESS(BCryptGenRandom(nullptr, reinterpret_cast<PUCHAR>(out.data()),
                                  static_cast<ULONG>(out.size()), BCRYPT_USE_SYSTEM_PREFERRED_RNG)))
    return std::nullopt;
  return out;
}

} // namespace civ13::voice::crypto
