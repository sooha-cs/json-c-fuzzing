#include <json-c/json.h>
#include <string.h>
#include <unistd.h>
__AFL_FUZZ_INIT();

int main(void) {
#ifdef __AFL_HAVE_MANUAL_CONTROL
  __AFL_INIT();
#endif
  unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;
  while (__AFL_LOOP(10000)) {
    int len = __AFL_FUZZ_TESTCASE_LEN;
    struct json_tokener *tok = json_tokener_new();
    struct json_object *obj =
        json_tokener_parse_ex(tok, (const char *)buf, len);
    if (obj) {
      /* exercise serialization too, not just parsing */
      const char *s = json_object_to_json_string_ext(obj, JSON_C_TO_STRING_PRETTY);
      if (s) (void)strlen(s);
      json_object_put(obj);
    }
    json_tokener_free(tok);
  }
  return 0;
}
