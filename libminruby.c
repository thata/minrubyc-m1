// libminruby.c
#include <stdio.h>

long p(long n) {
    printf("%ld\n", n);
    return n;
}

// 組み込み関数テスト用
long my_add(long a, long b) {
    return a + b;
}
