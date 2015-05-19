line = nil
32.times do
  line = STDIN.gets
  printf "%02x" ,line[0..7].to_i(2)
  printf "%02x" ,line[8..15].to_i(2)
end
