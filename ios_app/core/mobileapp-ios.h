#include <CoreFoundation/CoreFoundation.h>

typedef struct {
  int32_t status;
  CFStringRef session_json;
} FFISessionResult;

typedef struct {
  const char *string;
  int32_t int_;
} ParamStruct;

typedef struct {
  CFStringRef string;
  int32_t int_;
} ReturnStruct;

int32_t add_values(int32_t value1, int32_t value2);

FFISessionResult create_session(void);

CFStringRef greet(const char *who);

FFISessionResult join_session(const char *session_id);

void pass_struct(const ParamStruct *object);

void register_callback(void (*callback)(CFStringRef));

ReturnStruct return_struct(void);
