#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main(void) {
    char buf[64] = {0};
    ssize_t n = fread(buf, 1, sizeof buf - 1, stdin);
    if (n >= 4 && buf[0]=='F') {
        if (buf[1]=='U') {
            if (buf[2]=='Z') {
                if (buf[3]=='Z') {
                    volatile char *p = malloc(4);
                    p[10] = 'x';
                    printf("%d\n", p[10]);
                    free((void*)p);
                }
            }
        }
    }
    return 0;
}
