require 'openssl'

ROOT_PATH = './root.pem'

rsa = if File.exist?(ROOT_PATH)
  puts "reading..."
  OpenSSL::PKey::RSA.new(File.read(ROOT_PATH))
else
  puts "generating..."
  OpenSSL::PKey::RSA.generate(2048).tap do |k|
    File.open(ROOT_PATH, 'w') { |f| f.write k.to_pem }
  end
end

puts rsa.to_pem

r = OpenSSL::X509::Request.new.tap do |r|
  r.version = 1
  r.subject = OpenSSL::X509::Name.parse("/C=GB/O=Ghostworks Ltd/OU=Acropolis Development/CN=Acropolis Dev 1")
  r.public_key = rsa.public_key


  r.sign(rsa, OpenSSL::Digest::SHA256.new)
end

File.open('./mdm.csr', 'w') { |f| f.write r.to_pem.tap { puts _1 } }
