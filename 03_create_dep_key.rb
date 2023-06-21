require 'openssl'
require 'active_support'
require 'active_support/core_ext'

DEP_PATH = "./dep.pem"
DEP_PUB_PATH = "./dep.pub.pem"

dep = if File.exist?(DEP_PATH)
        OpenSSL::PKey::RSA.new(File.read(DEP_PATH))
      else
        OpenSSL::PKey::RSA.generate(2048).tap do |k|
          File.open(DEP_PATH, 'w') do |f|
            f.write k.to_pem
          end
        end
      end

# create a self-signed certificate
cert = OpenSSL::X509::Certificate.new.tap do |c|
  c.version = 1
  c.serial = 1
  c.public_key = dep.public_key

  c.issuer = c.subject = OpenSSL::X509::Name.parse("/C=GB/O=Ghostworks Ltd/OU=Acropolis Development DEP/CN=Acropolis DEP 1")

  c.not_before = Time.now
  c.not_after = Time.now + 1.year

  c.sign(dep, OpenSSL::Digest::SHA256.new)
end

File.open(DEP_PUB_PATH, 'w') do |f|
  f.write cert.to_pem
end
