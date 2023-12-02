// libminruby.c
#include <stdio.h>

long minruby_p(long n) {
    printf("%ld\n", n);
    return n;
}

// 組み込み関数テスト用
long minruby_my_add(long a, long b) {
    return a + b;
}
