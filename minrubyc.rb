# minrubyc.rb
require "minruby"

def gen(tree)
  if tree[0] == "lit"
    puts "\tmov x0, ##{tree[1]}"
  elsif %w(+ - * /).include?(tree[0])
    op = tree[0]
    expr1 = tree[1]
    expr2 = tree[2]

    # 評価結果一時保持用のスタック領域を確保
    puts "\tsub sp, sp, #16"

    # x0 へ格納された左辺評価結果をスタックへ積む
    gen(expr1)
    puts "\tstr x0, [sp, #0]"

    # x0 へ格納された右辺評価結果をスタックへ積む
    gen(expr2)
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
  else
    raise "invalid AST: #{tree}"
  end
end

tree = minruby_parse(ARGF.read)

puts "\t.text"
puts "\t.align 2"
puts "\t.globl _main"
puts "_main:"
# lr レジスタと fp レジスタをスタックに退避
puts "\tsub sp, sp, #16"
puts "\tstp fp, lr, [sp, #0]"

gen(tree)

# 終了する前に x0 レジスタの値を出力するため、p 関数を呼び出す
puts "\tbl _p"

# lr レジスタと fp レジスタをスタックから復元
puts "\tldp fp, lr, [sp, #0]"
puts "\tadd sp, sp, #16"

# 終了ステータスに 0 を返す
puts "\tmov w0, #10"
puts "\tret"
