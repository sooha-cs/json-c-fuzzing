#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main(void) {
    char buf[64];
    if (!fgets(buf, sizeof buf, stdin)) return 0;
    if (buf[0]=='F' && buf[1]=='U' && buf[2]=='Z' && buf[3]=='Z') {
        char *p = malloc(4);
        p[10] = 'x';   /* heap overflow, ASan should catch it */
        free(p);
    }
    return 0;
}
