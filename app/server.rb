require 'socket'
require 'json'

PORT = (ENV['PORT'] || 8080).to_i
COMPUTE = ENV['COMPUTE_TYPE'] || 'unknown'

server = TCPServer.new(PORT)
puts "listening on :#{PORT}"

loop do
  client = server.accept
  request = client.gets
  method, path = request&.split(' ')
  headers = {}
  while (line = client.gets.chomp) != ''
    k, v = line.split(': ', 2)
    headers[k.downcase] = v
  end

  len = headers['content-length'].to_i
  body_raw = len > 0 ? client.read(len) : '{}'
  payload = JSON.parse(body_raw) rescue {}

  if method == 'GET' && path == '/health'
    resp = { status: 'ok', compute: COMPUTE }.to_json
  elsif method == 'POST' && path == '/echo'
    resp = payload.merge('compute' => COMPUTE).to_json
  else
    resp = { error: 'not found' }.to_json
  end

  client.puts "HTTP/1.1 200 OK"
  client.puts "Content-Type: application/json"
  client.puts "Content-Length: #{resp.bytesize}"
  client.puts ''
  client.puts resp
  client.close
end
