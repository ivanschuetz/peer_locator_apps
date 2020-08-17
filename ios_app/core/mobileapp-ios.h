#include <CoreFoundation/CoreFoundation.h>

#if defined(TARGET_OS_IOS)
typedef struct {
  int32_t status;
  CFStringRef keys_str;
} FFIJoinSessionResult;
#endif

#if defined(TARGET_OS_IOS)
typedef struct {
  const char *string;
  int32_t int_;
} ParamStruct;
#endif

#if defined(TARGET_OS_IOS)
typedef struct {
  CFStringRef string;
  int32_t int_;
} ReturnStruct;
#endif

#if defined(TARGET_OS_IOS)
int32_t add_values(int32_t value1, int32_t value2);
#endif

#if defined(TARGET_OS_IOS)
CFStringRef greet(const char *who);
#endif

#if defined(TARGET_OS_IOS)
FFIJoinSessionResult join_session(const char *session_id);
#endif

#if defined(TARGET_OS_IOS)
void pass_struct(const ParamStruct *object);
#endif

#if defined(TARGET_OS_IOS)
void register_callback(void (*callback)(CFStringRef));
#endif

#if defined(TARGET_OS_IOS)
ReturnStruct return_struct(void);
#endif
