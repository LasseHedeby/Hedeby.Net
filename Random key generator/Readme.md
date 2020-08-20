# Random key generator
**Date:** 2016-02-20

I’ve made a random key generator for a S7-1200 PLC. It uses a random integer generator from Siemens to select the character position in a string of charactors and then add this particular character to a new string. This new string is the unique key.

The random integer generator reads the realtime clock in the CPU and uses the nanosecond data type for random integer generator.

> __This is not at truly random, unique safe generator that can be used in cryptography or other ways to secure anything. It can add an extra level of security but it can also be predicted.__

```pascal
// Reset in every cycle
#tempError  := False;
#tempStatus := #NO_JOB;
 
// Rising edge on execute
#statExecuteTrig   := #execute AND NOT #statExecuteMemory;
#statExecuteMemory := #execute;
 
// Generate key on rising edge
IF #statExecuteTrig THEN
  // Define list of charactors
  #tempCharactors := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210-';
  #tempCharLength := LEN(#tempCharactors);
 
  // Charactor loop
  #tempString := '';
  #statRandomInt := 0;
  FOR #tempIndex := 0 TO (#length - 1) DO
    #tempRepeat := 0; // Prevent cycle time overflow
    REPEAT
      #tempRepeat := #tempRepeat + 1;
      // Generate a random number for charactor index
      #tempRandomInt := "LGF_RandomInt"(minValue := 1, maxValue := #tempCharLength);
    UNTIL (#statRandomInt <> #tempRandomInt) OR (#tempRepeat > 4) // Prevent dublicates next to each other
    END_REPEAT;
    // Add to string
    #tempString := CONCAT(IN1 := #tempString, IN2 := MID(IN := #tempCharactors, P := #tempRandomInt, L := 1));
    // Save last random int
    #statRandomInt := #tempRandomInt;
  END_FOR;
 
  // Write key and length
  #uniqueKey  := #tempString;
  #keyLength  := LEN(#tempString);
  #tempStatus := #JOB_COMPLETE;
END_IF;
 
// Reset if not execute
IF NOT #execute THEN
  #uniqueKey := '';
  #keyLength := 0;
END_IF;
 
// Update outputs
#error  := #tempError;
#status := #tempStatus;
```
