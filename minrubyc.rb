# minrubyc.rb
require "minruby"

# 引数用レジスタの一覧
PARAM_REGISTERS = %w(x0 x1 x2 x3 x4 x5 x6 x7)

# tree 内に含まれる、var_assign で定義される変数名の一覧
def var_names(tree)
  if tree[0] == "var_assign"
    [tree[1]]
  elsif tree[0] == "stmts"
    arr = []
    tree[1..].each do |statement|
      arr += var_names(statement)
    end
    arr
  elsif tree[0] == "if"
    arr = []
    arr += var_names(tree[2])
    if tree[3]
      arr += var_names(tree[3])
    end
    arr
  elsif tree[0] == "while"
    puts "\t// while: #{tree}"
    var_names(tree[2])
  else
    []
  end
end

# スタックフレーム上の変数のアドレスをフレームポインタ(fp)からのオフセットとして返す
# 例：
#   ひとつ目の変数のアドレス = フレームポインタ(fp) + 16
#   ふたつ目の変数のアドレス = フレームポインタ(fp) + 24
#   ふたつ目の変数のアドレス = フレームポインタ(fp) + 32
#   ...
def var_offset(var, env)
  # 変数1つにつき8バイトの領域が必要
  env.index(var) * 8 + 16
end

# ユーザー定義関数を構文木より抽出
def func_defs(tree)
  if tree[0] == "func_def"
    {
      # 関数名をキーにして [関数名, 引数, 関数本体] を格納
      tree[1] => tree[1..]
    }
  elsif tree[0] == "stmts"
    tmp_hash = {}
    tree[1..].each do |stmt|
      tmp_hash.merge!(func_defs(stmt))
    end
    tmp_hash
  else
    {}
  end
end

# 構文木をアセンブリコードとして出力
def gen(tree, env)
  if tree[0] == "lit"
    puts "\tmov x0, ##{tree[1]}"
  elsif %w(+ - * / == != < <= > >=).include?(tree[0])
    op = tree[0]
    expr1 = tree[1]
    expr2 = tree[2]

    # 評価結果一時保持用のスタック領域を確保
    puts "\tsub sp, sp, #16"

    # x0 へ格納された左辺評価結果をスタックへ積む
    gen(expr1, env)
    puts "\tstr x0, [sp, #0]"

    # x0 へ格納された右辺評価結果をスタックへ積む
    gen(expr2, env)
    puts "\tstr x0, [sp, #8]"

    # スタックへ積んだ評価結果を x1 レジスタと x0 レジスタへロード
    puts "\tldr x1, [sp, #8]"
    puts "\tldr x0, [sp, #0]"

    # 演算結果を x0 へ格納
    case op
    when "+"
      puts "\tadd x0, x0, x1"
    when "-"
      puts "\tsub x0, x0, x1"
    when "*"
      puts "\tmul x0, x0, x1"
    when "/"
      puts "\tsdiv x0, x0, x1"
    when "=="
      puts "\tcmp x0, x1"
      puts "\tcset x0, eq"
    when "!="
      puts "\tcmp x0, x1"
      puts "\tcset x0, ne"
    when "<"
      puts "\tcmp x0, x1"
      puts "\tcset x0, lt"
    when "<="
      puts "\tcmp x0, x1"
      puts "\tcset x0, le"
    when ">"
      puts "\tcmp x0, x1"
      puts "\tcset x0, gt"
    when ">="
      puts "\tcmp x0, x1"
      puts "\tcset x0, ge"
    else
      raise "invalid operator: #{op}"
    end

    # スタックを破棄
    puts "\tadd sp, sp, #16"
  elsif tree[0] == "func_def"
    # 関数の定義はコンパイル時にコードとして出力されるため、実行時には何も行わなくて良い
  elsif tree[0] == "func_call"
    name, *args = tree[1..]

    # 引数用のレジスタは8つしかないので、引数が8個以上の場合はエラー
    raise "too many arguments (given #{args.size}, expected 8)" if args.size > 8

    # 引数を評価してスタックへ積む
    args.reverse.each do |arg|
      gen(arg, env)
      puts "\tsub sp, sp, #16"
      puts "\tstr x0, [sp, #0]"
    end

    # スタックへ詰んだ引数の値を、引数用レジスタへセット
    args.each_with_index do |arg, i|
      puts "\tldr #{PARAM_REGISTERS[i]}, [sp, #0]"
      puts "\tadd sp, sp, #16"
    end

    # 関数呼び出し
    puts "\tbl _minruby_#{name}"
  elsif tree[0] == "stmts"
    tree[1..].each do |stmt|
      gen(stmt, env)
    end
  elsif tree[0] == "var_assign"
    name, expr = tree[1], tree[2]

    # 評価した値をスタック上のローカル変数領域へ格納
    gen(expr, env)
    puts "\tstr x0, [fp, ##{var_offset(name, env)}]"
  elsif tree[0] == "var_ref"
    name = tree[1]

    # ローカル変数領域からx0へ値をロード
    puts "\tldr x0, [fp, ##{var_offset(name, env)}]"
  elsif tree[0] == "if"
    cond, texpr, fexpr = tree[1], tree[2], tree[3]
    # 条件式を評価
    puts "\t// 条件式を評価"
    gen(cond, env)
    puts "\tcmp x0, #0"

    puts "\tbeq .Lelse#{tree.object_id}"

    # 真の場合はtexprを評価
    puts "\t// 真の場合"
    gen(texpr, env)
    puts "\tb .Lendif#{tree.object_id}"
    puts ".Lelse#{tree.object_id}:"
    # 偽の場合はfexprを評価
    puts "\t// 偽の場合"
    gen(fexpr, env) if fexpr
    puts ".Lendif#{tree.object_id}:"
  elsif tree[0] == "while"
    cond, body = tree[1], tree[2]
    puts ".Lwhile#{tree.object_id}:"
    gen(cond, env)
    puts "\tcmp x0, #0"
    puts "\tbeq .Lendwhile#{tree.object_id}"
    gen(body, env)
    puts "\tb .Lwhile#{tree.object_id}"
    puts ".Lendwhile#{tree.object_id}:"
  else
    raise "invalid AST: #{tree}"
  end
end

# 関数定義をアセンブリコードとして出力
def gen_func_def(func_def)
  name, params, body = func_def
  lenv = var_names(body)
  env = params + lenv

  # 名前が衝突しないように、関数名の先頭に _minruby_ を付与
  puts "\t.globl _minruby_#{name}"
  puts "_minruby_#{name}:"

  # 関数プロローグ
  lvar_size = env.size * 8
  puts "\tsub sp, sp, ##{16 + (lvar_size % 16 == 0 ? lvar_size : lvar_size + 8)}" # NOTE: スタックのサイズは16の倍数でなければならない
  puts "\tstp fp, lr, [sp, #0]"
  puts "\tmov fp, sp"
  # スタック上のパラメータ領域を初期化
  params.each_with_index do |param, i|
    puts "\tstr #{PARAM_REGISTERS[i]}, [fp, ##{var_offset(param, env)}]"
  end
  # ローカル変数を初期化
  lenv.each do |var|
    puts "\tmov x0, #0"
    puts "\tstr x0, [fp, ##{var_offset(var, env)}]"
  end

  gen(body, env)

  # 関数エピローグ
  puts "\tldp fp, lr, [sp, #0]"
  puts "\tadd sp, sp, ##{16 + (lvar_size % 16 == 0 ? lvar_size : lvar_size + 8)}" # NOTE: スタックのサイズは16の倍数でなければならない
  puts "\tret"
end

tree = minruby_parse(ARGF.read)
env = var_names(tree)
lvar_size = env.size * 8

# ユーザー定義関数を構文木より抽出
func_defs = func_defs(tree)

puts "\t.text"
puts "\t.align 2"

# ユーザー定義関数をアセンブリコードとして出力
func_defs.values.each do |func_def|
  gen_func_def(func_def)
end

# メイン関数
puts "\t.globl _main"
puts "_main:"

# スタックフレームを確保
# NOTE: スタックのサイズは16の倍数でなければならない
puts "\tsub sp, sp, ##{16 + (lvar_size % 16 == 0 ? lvar_size : lvar_size + 8)}"

# lr レジスタと fp レジスタをスタックに退避
puts "\tstp fp, lr, [sp, #0]"
puts "\tmov fp, sp"

# ローカル変数を0で初期化
env.each do |var|
  puts "\tmov x0, #0"
  puts "\tstr x0, [fp, ##{var_offset(var, env)}]"
end

gen(tree, env)

# lr レジスタと fp レジスタをスタックから復元
puts "\tldp fp, lr, [sp, #0]"

# スタックフレームを破棄
# NOTE: スタックのサイズは16の倍数でなければならない
puts "\tadd sp, sp, ##{16 + (lvar_size % 16 == 0 ? lvar_size : lvar_size + 8)}"

# 終了ステータスに 0 を返す
puts "\tmov w0, #10"
puts "\tret"
