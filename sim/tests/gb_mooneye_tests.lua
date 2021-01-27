require("vsim_comm")
require("luareg")

filenames = {}
-- should be ok
table.insert(filenames, "mooneye\\tim00.gb")
table.insert(filenames, "mooneye\\tim00_div_trigger.gb")
table.insert(filenames, "mooneye\\tima_reload.gb")
table.insert(filenames, "mooneye\\tima_write_reloading.gb")
table.insert(filenames, "mooneye\\tma_write_reloading.gb")
-- known fail
table.insert(filenames, "mooneye\\rapid_toggle.gb")


for filenr = 1, #filenames do

   reg_set(0, gameboy.Reg_GB_on)
   wait_ns(10000)
   reg_set_file(filenames[filenr], 0, 0, 0)
   wait_ns(10000)
   reg_set(1, gameboy.Reg_GB_on)
   
   for i = 0, 100 do
      wait_ns(1000000)
      
      local done = reg_get(gameboy.Reg_GB_TestDone)
      if (done == 1) then
         local ok = reg_get(gameboy.Reg_GB_TestOk)
         if (ok == 1) then
            print ("Test passed: ", filenames[filenr])
         else
            print ("Test failed: ", filenames[filenr])
         end
         break
      end
   end
end

print ("Testrun finished")
