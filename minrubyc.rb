# minrubyc.rb
require "minruby"

tree = minruby_parse(ARGF.read)

puts "\t.text"
puts "\t.align 2"
puts "\t.globl _main"
puts "_main:"
# lr レジスタと fp レジスタをスタックに退避
puts "\tsub sp, sp, #16"
puts "\tstp fp, lr, [sp, #0]"

if tree[0] == "lit"
  # 整数リテラルの値を x0 レジスタへ格納
  puts "\tmov x0, ##{tree[1]}"
else
  raise "invalid AST: #{tree}"
end

# 終了する前に x0 レジスタの値を出力するため、p 関数を呼び出す
puts "\tbl _p"

# lr レジスタと fp レジスタをスタックから復元
puts "\tldp fp, lr, [sp, #0]"
puts "\tadd sp, sp, #16"

# 終了ステータスに 0 を返す
puts "\tmov w0, #10"
puts "\tret"
