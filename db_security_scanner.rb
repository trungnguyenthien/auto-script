#!/usr/bin/env ruby
# -*- encoding : utf-8 -*-

# ==============================================================================
# TÊN SCRIPT: db_security_scanner.rb
# CHỨC NĂNG: Quét SQLite sử dụng Regex "Universal" cho Số điện thoại toàn cầu,
#            Email và Keywords nhạy cảm.
# ==============================================================================

require 'sqlite3' # Yêu cầu: gem install sqlite3

# 1. ĐỊNH NGHĨA REGEX TỔNG HỢP
REGEX_PATTERNS = {
  # Email tiêu chuẩn
  email: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
  
  # Regex Số điện thoại Toàn cầu (Universal Phone Regex)
  # Giải thích: 
  # - Bắt đầu bằng dấu + (mã quốc gia) hoặc số 0.
  # - Cho phép dấu ngoặc đơn, dấu gạch ngang, dấu chấm hoặc khoảng trắng.
  # - Yêu cầu độ dài từ 7 đến 15 chữ số (theo chuẩn quốc tế E.164).
  phone_universal: /(?:\+|00|0)[1-9](?:[ .\-\(\)]*\d){6,14}/
}

# 2. DANH SÁCH TỪ KHÓA NHẠY CẢM
KEYWORDS = [
  'token', 'access_token', 'refresh_token', 'auth', 'session', 'jwt', 'cookie', 
  'password', 'passwd', 'secret', 'key', 'apiKey', 'client_id', 'client_secret',
  'email', 'phone', 'username', 'fullname', 'address', 'birthday', 'dob', 'gender',
  'identity', 'passport', 'license', 'ssn', 'biometric',
  'card', 'credit', 'debit', 'cvv', 'cvc', 'bank', 'account', 'balance', 'transaction',
  'wallet', 'vnpay', 'momo', 'stripe', 'paypal', 'zalopay', 'shopeepay',
  'aws', 's3', 'bucket', 'firebase', 'google_api', 'database_url', 'endpoint', 'host',
  'user_id', 'profile', 'credential', 'private', 'history', 'location', 'gps'
]

def print_help
  puts "==============================================================="
  puts "SỬ DỤNG: ruby db_security_scanner.rb <đường_dẫn_file_db>"
  puts "==============================================================="
end

if ARGV.empty? || ARGV[0] == "-h" || ARGV[0] == "--help"
  print_help
  exit
end

db_path = File.expand_path(ARGV[0])

unless File.exist?(db_path)
  puts "❌ LỖI: Không tìm thấy tệp tin tại: #{db_path}"
  exit
end

puts "🔍 ĐANG QUÉT CHUYÊN SÂU (UNIVERSAL REGEX): #{File.basename(db_path)}"
puts "---"

begin
  db = SQLite3::Database.open db_path
  db.readonly = true
  
  tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'")
  found_count = 0

  tables.flatten.each do |table_name|
    begin
      # Kiểm tra cấu trúc cột
      columns = db.prepare("SELECT * FROM #{table_name} LIMIT 1").columns
    rescue
      next 
    end
    
    # Kiểm tra tên CỘT
    columns.each do |col|
      KEYWORDS.each do |key|
        if col.downcase.include?(key)
          puts "⚠️  [COLUMN] Bảng [#{table_name}] có cột nghi vấn: '#{col}'"
          found_count += 1
        end
      end
    end

    # Quét DỮ LIỆU
    begin
      db.execute("SELECT * FROM #{table_name}") do |row|
        row.each_with_index do |cell, idx|
          next if cell.nil?
          cell_str = cell.to_s
          
          match_found = false
          match_label = ""

          # Kiểm tra Regex
          REGEX_PATTERNS.each do |type, regex|
            if cell_str =~ regex
              # Kiểm tra bổ sung cho số điện thoại để tránh bắt nhầm ID dài
              if type == :phone_universal && cell_str.gsub(/[^0-9]/, '').length < 7
                next
              end
              
              match_found = true
              match_label = "REGEX_#{type.upcase}"
              break
            end
          end

          # Kiểm tra Keywords
          if !match_found
            KEYWORDS.each do |key|
              if cell_str.downcase.include?(key)
                match_found = true
                match_label = "KEYWORD_#{key.upcase}"
                break
              end
            end
          end

          if match_found
            puts "🔐 [#{match_label}] tại [#{table_name}] -> Cột [#{columns[idx]}]:"
            puts "   >> Giá trị: #{cell_str[0..120].gsub(/\n/, ' ').strip}..." 
            puts "---"
            found_count += 1
          end
        end
      end
    rescue => e; end
  end

  puts "✅ HOÀN TẤT KIỂM TRA."
  puts "=> Tìm thấy #{found_count} vị trí nghi vấn."

rescue SQLite3::Exception => e
  puts "❌ LỖI SQLITE: #{e.message}"
ensure
  db.close if db
end