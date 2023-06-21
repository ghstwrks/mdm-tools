require 'openssl'
require 'base64'
require 'plist'
require 'http'

CLIENT_PATH = './client.pem'
CLIENT_CSR_PATH = './client.csr'

http = HTTP.headers('User-Agent' => 'Acropolis (dev) [Ghostworks Ltd]').follow

get_cert = -> (path) do
  puts "[get_cert] path: #{path}"
  b = http.get(path).body.to_s
  puts "[get_cert] cert: #{b.inspect}"

  OpenSSL::X509::Certificate.new(b)
end

puts "getting chain certs..."

apple_wwdr = get_cert.('http://certs.apple.com/wwdrg3.der')
apple_root = get_cert.('http://www.apple.com/appleca/AppleIncRootCertificate.cer')

# create client key
rsa = if File.exist?(CLIENT_PATH)
        puts "reading..."
        OpenSSL::PKey::RSA.new(File.read(CLIENT_PATH))
      else
        puts "generating..."
        OpenSSL::PKey::RSA.generate(2048).tap do |k|
          File.open(CLIENT_PATH, 'w') { |f| f.write k.to_pem }
        end
      end

# create client csr
csr = if File.exist?(CLIENT_CSR_PATH)
        puts "reading csr..."
        OpenSSL::X509::Request.new(File.read(CLIENT_CSR_PATH))
      else
        puts "generating csr..."
        OpenSSL::X509::Request.new.tap do |r|
          r.version = 1
          r.subject = OpenSSL::X509::Name.parse("/C=GB/O=Ghostworks Ltd/OU=Acropolis Development/CN=Acropolis Client 1")
          r.public_key = rsa.public_key

          r.sign(rsa, OpenSSL::Digest::SHA256.new)

          File.open(CLIENT_CSR_PATH, 'w') do |f|
            f.write(r.to_pem.tap do
              puts "csr generated!"
              puts _1
            end)
          end
        end
      end

# "sign" CSR DER with MDM cert/key
vendor = OpenSSL::PKey::RSA.new(File.read("./root.pem"))

res = vendor.sign(OpenSSL::Digest::SHA256.new, csr.to_der)
sig64 = Base64.strict_encode64(res)

upload = {
  'PushCertSignature' => sig64,
  'PushCertCertificateChain' => [vendor_cert, apple_wwdc, apple_root].map(&:to_pem).join(""),
  'PushCertRequestCSR' => Base64.strict_encode64(csr.to_der)
}

File.open('./upload_b64.plist', 'w') do |f|
  f.write Base64.strict_encode64(upload.to_plist)
end

puts "it is written. good luck."
