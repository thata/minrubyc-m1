# minrubyc.rb
require "minruby"

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

def gen(tree, env)
  if tree[0] == "lit"
    puts "\tmov x0, ##{tree[1]}"
  elsif %w(+ - * /).include?(tree[0])
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
    else
      raise "invalid operator: #{op}"
    end

    # スタックを破棄
    puts "\tadd sp, sp, #16"
  elsif tree[0] == "func_call" && tree[1] == "p"
    # p 関数を呼び出す
    expr = tree[2]
    gen(expr, env)
    puts "\tbl _p"
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
  else
    raise "invalid AST: #{tree}"
  end
end

tree = minruby_parse(ARGF.read)
env = var_names(tree)
lvar_size = env.size * 8

puts "\t.text"
puts "\t.align 2"
puts "\t.globl _main"
puts "_main:"

# スタックフレームを確保
# NOTE: スタックのサイズは16の倍数でなければならない
puts "\tsub sp, sp, ##{16 + (lvar_size % 16 == 0 ? lvar_size : lvar_size + 8)}"

# lr レジスタと fp レジスタをスタックに退避
puts "\tstp fp, lr, [sp, #0]"
puts "\tmov fp, sp"

gen(tree, env)

# lr レジスタと fp レジスタをスタックから復元
puts "\tldp fp, lr, [sp, #0]"

# スタックフレームを破棄
# NOTE: スタックのサイズは16の倍数でなければならない
puts "\tadd sp, sp, ##{16 + (lvar_size % 16 == 0 ? lvar_size : lvar_size + 8)}"

# 終了ステータスに 0 を返す
puts "\tmov w0, #10"
puts "\tret"
