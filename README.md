# total_counters
junkbox of code to count on/off cycles, moto-hours counters and shaft revolutions counters, Dreamed by BingAI 


Each of those programs is designed for simple devices that count :

-on/off cycles (how many times device was powered on, f.e. car starter motor) 
 usually an "on" counter counting how many times device was powered. 
 With eeprom load levelling or without. 
 Total count is emitted on serial pin, but it can be easily modified with my IR_serial library to emit IR serial output so it can be readed contactless. 

-moto hours of device (f.e. compressor of a fridge) 

-shaft revolution counts of device (f.e. washing machine motor)

At current stage it's a junkbox with example code to get one started, some of it works out of the box, some needs to be improved or fixed.

  
