#FirstPacket SeqNr0 = {
#    TransmissionId(16),
#    SeqNr(32),
#    MaxSeqNr(32),
#    Filename(8...2048)
#}

#Packet SeqNr1 = {
#    TransmissionId(16),
#    SeqNr(32),
#    Data(..)
#}
 
#LastPacket SeqNr1 = {
#    TransmissionId(16),
#    SeqNr(32),
#    MD5(128)
#}

require 'socket'
require 'digest'

# Settings
PORT = 5000
OUTPUT_PREFIX = 'received_'

# State
received = {}
max_seq = nil
expected_md5 = nil
filename = 'output.dat'

puts "Warte auf Daten..."

socket = UDPSocket.new
socket.bind('0.0.0.0', PORT)

loop do
  packet, _ = socket.recvfrom(4096)
  next if packet.nil? || packet.empty?

  # Parse header (TX.ru: tid=2 bytes, seq=4 bytes)
  tid = packet[0,2]
  seq = packet[2,4].unpack1('N')

  if seq == 0
    # First packet: TransmissionId (2), SeqNr (4), MaxSeqNr (4), Filename (8-2048)
    #https://apidock.com/ruby/Array/pack
    max_seq = packet[6,4].unpack1('N')
    fname = packet[10..-1].delete("\0")
    filename = fname unless fname.empty?
    puts "Empfange Datei: #{filename}, Pakete: #{max_seq}"
  elsif max_seq && seq == max_seq + 1
    # Last packet: TransmissionId (2), SeqNr (4), MD5 (16)
    expected_md5 = packet[6,16]
    puts "Letztes Paket erhalten. MD5: #{expected_md5.unpack1('H*')}"
    break
  else
    # Data packet: TransmissionId (2), SeqNr (4), Data
    data = packet[6..-1]
    received[seq] = data
    puts "Paket #{seq} erhalten (#{data.bytesize} Bytes)"
  end
end

socket.close

# Write file if all packets received
if max_seq && expected_md5 && received.size == max_seq
  File.open(OUTPUT_PREFIX + filename, 'wb') do |f|
    (1..max_seq).each do |seq|
      f.write(received[seq] || "")
    end
  end
  file_data = File.binread(OUTPUT_PREFIX + filename)
  actual_md5 = Digest::MD5.digest(file_data)
  if actual_md5 == expected_md5
    puts "Datei korrekt empfangen und gespeichert als #{OUTPUT_PREFIX + filename}"
  else
    puts "MD5 Fehler. Datei beschädigt."
  end
else
  puts "Nicht alle Pakete empfangen."
end
