#!/usr/bin/env ruby

# Kiểm tra xem người dùng có truyền tham số file vào không
if ARGV.empty?
  puts "Sử dụng: ruby convert_plist.rb <path_to_file.plist>"
  exit
end

input_file = ARGV[0]
expanded_path = File.expand_path(input_file)

# Kiểm tra file có tồn tại không
unless File.exist?(expanded_path)
  puts "❌ Lỗi: Không tìm thấy file tại #{input_file}"
  exit
end

# Tạo tên file output theo định dạng *.raw.plist
output_file = expanded_path.sub(/\.plist$/, "") + ".raw.plist"

# Kiểm tra xem file có phải là định dạng Binary không bằng lệnh 'file'
file_type = `file -b "#{expanded_path}"`

if file_type.include?("Apple binary property list")
  puts "📂 Phát hiện định dạng: Binary Plist"
  
  # Thực hiện convert sang định dạng XML (Plaintext) bằng plutil
  # -convert xml1: chuyển sang XML
  # -o: chỉ định file đầu ra
  system("plutil -convert xml1 \"#{expanded_path}\" -o \"#{output_file}\"")
  
  if $?.success?
    puts "✅ Chuyển đổi thành công!"
    puts "📄 File đầu ra: #{output_file}"
  else
    puts "❌ Có lỗi xảy ra trong quá trình chuyển đổi."
  end
else
  puts "ℹ️ File này không phải định dạng Binary hoặc đã là Plaintext."
  # Nếu bạn vẫn muốn tạo bản copy .raw.plist cho đồng bộ:
  FileUtils.cp(expanded_path, output_file) if defined?(FileUtils)
  puts "📄 Đã tạo bản sao tại: #{output_file}"
end