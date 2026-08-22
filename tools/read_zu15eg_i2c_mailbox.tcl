connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*A53*#0"}
configparams force-mem-access 1
rst -processor
after 500
set magic [mrd -value 0xFFFE0000]
set state [mrd -value 0xFFFE0004]
set stage [mrd -value 0xFFFE0008]
set driver_status [mrd -value 0xFFFE000C]
set eeprom_byte0 [mrd -value 0xFFFE0010]
puts [format "MAGIC=0x%08X" $magic]
puts [format "STATE=0x%08X" $state]
puts "STAGE=$stage"
puts [format "DRIVER_STATUS=0x%08X" $driver_status]
puts [format "EEPROM_BYTE0=0x%02X" $eeprom_byte0]
disconnect
