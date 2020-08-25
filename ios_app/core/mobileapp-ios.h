#include <CoreFoundation/CoreFoundation.h>

enum CoreLogLevel {
  Trace = 0,
  Debug = 1,
  Info = 2,
  Warn = 3,
  Error = 4,
};
typedef uint8_t CoreLogLevel;

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  int32_t status;
  bool is_ready;
} FFIAckResult;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  int32_t status;
  CFStringRef private_key;
  CFStringRef public_key;
} FFIKeyPairResult;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  int32_t status;
  CFStringRef session_json;
} FFISessionResult;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  int32_t status;
  CFStringRef session_json;
} FFIParticipantsResult;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  const char *string;
  int32_t int_;
} ParamStruct;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  CoreLogLevel level;
  CFStringRef text;
  int64_t time;
} CoreLogMessage;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
typedef struct {
  CFStringRef string;
  int32_t int_;
} ReturnStruct;
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
int32_t add_values(int32_t value1, int32_t value2);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
FFIAckResult ffi_ack(const char *uuid, int32_t stored_participants);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
int32_t ffi_bootstrap(CoreLogLevel level, bool app_only);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
FFIKeyPairResult ffi_create_key_pair(void);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
FFISessionResult ffi_create_session(const char *session_id, const char *key);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
FFISessionResult ffi_join_session(const char *session_id, const char *key);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
FFIParticipantsResult ffi_participants(const char *session_id);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
CFStringRef greet(const char *who);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
void pass_struct(const ParamStruct *object);
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
void register_callback(void (*callback)(CFStringRef));
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
int32_t register_log_callback(void (*log_callback)(CoreLogMessage));
#endif

#if (defined(TARGET_OS_IOS) || defined(TARGET_OS_MACOS))
ReturnStruct return_struct(void);
#endif
