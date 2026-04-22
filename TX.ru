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


# Import required libraries
# 'socket' is used for UDP socket communication
require 'socket'
# 'digest' is used for MD5 hashing of file data
require 'digest'


# Builds the first packet to initiate the file transfer.
# Format: TransmissionId (2 bytes), SeqNr (4 bytes), MaxSeqNr (4 bytes), Filename (8-2048 bytes)
# transmission_id: unique identifier for this transfer (string or number)
# max_seq: total number of data packets to be sent (integer)
# filename: name of the file being sent (string)
def build_first_packet(transmission_id, max_seq, filename)
  # TransmissionId: use only the lower 16 bits (2 bytes)
  tid = transmission_id.to_i & 0xFFFF
  # Sequence number for the first packet is always 0
  seq = 0
  # Encode filename as binary, pad to at least 8 bytes, max 2048 bytes
  fname = filename.encode('ASCII-8BIT').ljust(8, "\0")[0,2048]

  # Pack header fields: n = 16-bit unsigned, N = 32-bit unsigned
  #https://apidock.com/ruby/Array/pack
  header = [tid, seq, max_seq].pack("n N N")
  # Concatenate header and filename
  header + fname
end

# Builds a data packet.
# Format: TransmissionId (2 bytes), SeqNr (4 bytes), Data (up to 1024 bytes)
# transmission_id: unique identifier for this transfer
# seq_nr: sequence number of this packet
# data: chunk of file data (string)
def build_packet(transmission_id, seq_nr, data)
  tid = transmission_id.to_i & 0xFFFF
  # Pack header and append data
  #https://apidock.com/ruby/Array/pack
  [tid, seq_nr].pack("n N") + data.to_s
end

# Builds the last packet, which contains the MD5 hash for integrity check.
# Format: TransmissionId (2 bytes), SeqNr (4 bytes), MD5 (16 bytes)
# transmission_id: unique identifier for this transfer
# seq_nr: sequence number for the last packet (max_seq + 1)
# data: the entire file content (string)
def build_last_packet(transmission_id, seq_nr, data)
  tid = transmission_id.to_i & 0xFFFF
  # Calculate MD5 hash of the file data
  md5 = Digest::MD5.digest(data)
  # Pack header and append MD5
  #https://apidock.com/ruby/Array/pack
  [tid, seq_nr].pack("n N") + md5
end


# Main function to send a file over UDP using the custom protocol.
# filename: path to the file to send
# destination_ip: IP address of the receiver
# destination_port: UDP port of the receiver
def send_file(filename, destination_ip, destination_port)
  # Generate a unique transmission ID for this session (e.g., "TX123")
  transmission_id = "TX#{rand(1000)}"
  # Read the entire file as binary data
  data = File.binread(filename)
  # Calculate the number of data packets needed (each up to 1024 bytes)
  max_seq = (data.size / 1024.0).ceil

  # Create a UDP socket and connect to the receiver
  socket = UDPSocket.new
  socket.connect(destination_ip, destination_port)

  # --- Send the first packet (metadata) ---
  # Contains transmission ID, sequence number 0, max sequence number, and filename
  first_packet = build_first_packet(transmission_id, max_seq, File.basename(filename))
  socket.send(first_packet, 0)

  # --- Send all data packets ---
  # Each packet contains a chunk of the file data
  (1..max_seq).each do |seq_nr|
    # Extract the next 1024-byte chunk (or less for the last packet)
    chunk = data[(seq_nr-1) * 1024, 1024] || ""
    packet = build_packet(transmission_id, seq_nr, chunk)
    socket.send(packet, 0)
  end

  # --- Send the last packet (MD5 hash) ---
  # Used by the receiver to verify file integrity
  last_packet = build_last_packet(transmission_id, max_seq + 1, data)
  socket.send(last_packet, 0)
  # Close the socket after sending all packets
  socket.close
end



# Example usage: send 'example.txt' to localhost on port 5000
destination_ip = '127.0.0.1'      # Receiver IP address
destination_port = 5000           # Receiver UDP port

# Call the send_file function to start the transfer
send_file('example.txt', destination_ip, destination_port)