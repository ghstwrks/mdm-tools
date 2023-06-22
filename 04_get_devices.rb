require 'openssl'
require 'http'
require 'json'
require 'logger'
require 'securerandom'
require 'oauth'
require 'pp'

# advanced debug technique
HTTP.default_options = HTTP::Options.new(features: {
                                           logging: {
                                             logger: Logger.new(STDOUT)
                                           }
                                         })

# get the latest p7m file
p7m_file = Dir.glob('./*.p7m').sort.last

puts "latest token file: #{p7m_file}"

sm = OpenSSL::PKCS7.read_smime(File.read(p7m_file))

# Get DEP cert & key for decryption
dep = OpenSSL::X509::Certificate.new(File.read("./dep.pub.pem"))
dep_key = OpenSSL::PKey::RSA.new(File.read("./dep.pem"))

# Questionable API from OpenSSL here.
# TODO: read RFCs, & figure out if either Apple or Ruby's OpenSSL is wrong here.
data = sm.decrypt(dep_key, dep)

# BEGIN CRIMES
body = data.split(/\r?\n\r?\n/, 2).last
keys_json = body.match(/-----BEGIN MESSAGE-----\r?\n(.+)\r?\n-----END MESSAGE-----/)[1]
# END CRIMES

auth = JSON.parse keys_json

# consumer_key
# consumer_secret
# access_token
# access_secret

# CRIMES: library hackery (please remove once we understand oauth)
@consumer = OAuth::Consumer.new(auth['consumer_key'], auth['consumer_secret'], {
  site: 'https://mdmenrollment.apple.com',
  scheme: :header,
  http_method: :get,
})

at = OAuth::AccessToken.from_hash(@consumer, {
  oauth_token: auth['access_token'],
  oauth_token_secret: auth['access_secret']
})

res = at.get('/session')

session = JSON.parse res.body
# END OAUTH CRIMES

base = HTTP.headers('User-Agent' => 'Acropolis (dev) [Ghostworks Ltd]', 'X-Server-Protocol-Version' => 3)

# = Get account
http = base.headers('X-ADM-Auth-Session' => session['auth_session_token'])

res = http.get('https://mdmenrollment.apple.com/account')

account = res.parse

puts "account:"
pp account


# = Get devices

http = base.headers('X-ADM-Auth-Session' => res.headers['X-ADM-Auth-Session'])

res = http.post('https://mdmenrollment.apple.com/server/devices')

puts "res.status: #{res.status}"
puts "res.headers['X-ADM-Auth-Session']: '#{res.headers['X-ADM-Auth-Session']}'"
puts "res.body: #{res.body}"

list = res.parse

puts "=== DEVICES ==="
list['devices'].each do |device|
  puts "#{device['model']} -> #{device['serial_number']}"
end

puts "cursor: #{list['cursor']}"

# = Define a profile

# res.headers['X-ADM-Auth-Session']


# TODO: revive the following so we can avoid hacking up this oauth library
# http = HTTP #.headers('User-Agent' => 'Acropolis (dev) [Ghostworks Ltd]')

# # OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha1"), secret, signature_base_string)

# oscape = -> (s) do
#   URI::DEFAULT_PARSER.escape(s, /[^a-zA-Z0-9\-._~]/)
# end

# ts = Time.now.to_i.to_s
# nc = SecureRandom.hex(12)

# oauth_params = {
#   oauth_consumer_key: auth['consumer_key'],
#   oauth_token: auth['access_token'],
#   oauth_signature_method: 'HMAC-SHA1',
#   oauth_timestamp: ts,
#   oauth_nonce: nc,
#   oauth_version: '1.0'
# }.sort.to_h

# params_for_signing = -> (params) do
#   params.to_a.map { _1.join('=') }.join('&')
# end

# xs = oscape.(params_for_signing.(oauth_params))

# puts "xs: #{xs}"

# signature = OpenSSL::HMAC.digest(
#   OpenSSL::Digest.new("sha1"),
#   [auth['consumer_secret'], auth['access_secret']].map { oscape.(_1) }.join('&'),
#   ['GET', oscape.('https://mdmenrollment.apple.com/session'), xs].join('&')
# )

# # method, normalized_uri, normalized_parameters

# oauth_header = %{OAuth } + {
#   realm: 'ADM',
#   oauth_consumer_key: auth['consumer_key'],
#   oauth_token: auth['access_token'],
#   oauth_signature_method: 'HMAC-SHA1',
#   oauth_signature: oscape.(Base64.strict_encode64(signature)),
#   oauth_timestamp: ts,
#   oauth_nonce: nc,
#   oauth_version: '1.0'
# }.sort.to_h.map { _1.join('=') }.join(",")

# res = http.auth(oauth_header).get('https://mdmenrollment.apple.com/session')

# if res.status.success?
#   puts "success!"
# else
#   raise "failed to get MDM session"
# end


# puts "data: #{data.class} #{data.inspect}"

# d = OpenSSL::PKCS7.new(data)


# puts "d: #{d.class} #{d.data}"
