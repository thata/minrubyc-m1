Rubyで書かれたRubyサブセット言語のコンパイラ。Apple Mシリーズで動作します。

# Usage

事前に `minruby` gem をインストールしておく

```sh
gem install minruby
```

`samples/fib.rb` をコンパイルして AArch64 アセンブリを出力する

```sh
ruby minrubyc.rb sample/fib.rb > tmp.s
```

出力したアセンブリをコンパイルして実行する

```sh
$ gcc tmp.s libminruby.c
$ ./a.out
55
$
```

# Run tests

```sh
./test.sh
```
