#!/bin/bash

assert() {
    # expected の "\n" を改行コードをとして解釈させる
    expected=`echo -e "$1"`
    input="$2"

    echo "$input" > tmp.rb
    ruby minrubyc.rb tmp.rb > tmp.s
    gcc tmp.s libminruby.c -o tmp
    actual=`./tmp`

    if [ "$actual" = "$expected" ]; then
        echo "$input => $actual"
    else
        echo "$input => $expected expected, but got $actual"
        exit 1
    fi
}

# # putc
# assert "Hello!!" "putc 72; putc 101; putc 108; putc 108; putc 111; putc 33; putc 33"

# ユーザー定義関数
assert "50" "a = 10; def foo(a) b = 20; a + b; end; p foo(30)"
assert "55" "def fib(n) if (n < 2); n else fib(n - 1) + fib(n - 2); end; end; p fib(10)"
assert "20" "def foo(n) b = 2; n * b; end; p foo(10)"

# 組み込み関数
assert 5963 'p my_add(5900, 63)'

# while
assert 55 'sum = 0; i = 1; while (i <= 10); sum = sum + i; i = i + 1; end; p sum'
assert 55 'sum = 0; i = 1; while (i <= 10); one = 1; sum = sum + i; i = i + one; end; p sum'

# if
assert 42 'if (0 == 0); p(42); else p(43); end'
assert 43 'if (0 == 1); p(42); else p(43); end'
assert 44 'a = 44; if (a == 44); p a; end'
assert 45 'a = 40; if (a == 40); b = 5;  p a + b; end'
assert "10\n20\n0\n" 'a = 10; if (1); b = 20; else c = 30; end; p a; p b; p c'

# 比較演算
# 真の場合は1、偽の場合は0を返す
assert 1 'p(1 == 1)'
assert 0 'p(1 == 2)'
assert 0 'p(1 != 1)'
assert 1 'p(1 != 2)'
assert 1 'p(1 < 2)'
assert 0 'p(1 < 1)'
assert 1 'p(1 <= 2)'
assert 1 'p(1 <= 1)'
assert 0 'p(1 <= 0)'
assert 1 'p(2 > 1)'
assert 0 'p(1 > 1)'
assert 1 'p(2 >= 1)'
assert 1 'p(1 >= 1)'
assert 0 'p(0 >= 1)'

# 変数
assert "10\n20\n30\n" "a = 10; b = 20; c = 30; p a; p b; p c"
assert 30 'a = 10; b = 20; p a + b'
assert 10 'a = 10; p a'
assert 30 'a = 10; if a == 10; b = 20; p a + b; end'
assert 55 'i = 1; sum = 0; while i <= 10; one = 1; sum = sum + i; i = i + one; end; p(sum)'

# 複文
assert "10\n20\n" "p 10; p 20"

# 四則演算
assert "305" "p((10+20*30)/2)"
assert "5" "p 30/6"
assert "72" "p 8*9"
assert "20" "p 30-10"
assert "30" "p 10+20"

# 整数リテラル
assert "-10" "p(-10)"
assert "4649" "p 4649"

echo OK
