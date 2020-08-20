# Simple CRC32 Function For SIMATIC
**Date:** 2018-03-28

Simple CRC32 function for SIMATIC controllers.

```pascal
FUNCTION "FCCRC32Calc" : DWord
  { S7_Optimized_Access := 'TRUE' }
  VERSION : 0.1
  VAR_INPUT
    data : Array[0..4095] of Byte;
    length : Int;
  END_VAR
 
  VAR_TEMP
    rem : DWord;
    i : Int;
    j : Int;
  END_VAR
 
  VAR CONSTANT
    POLYNOMIAL : DWord := 16#ABCDEF01;  // Chose your polynomial here
  END_VAR
 
  BEGIN
  #rem := 16#ffffffff;
  FOR #i := 0 TO (#length-1) DO
    #rem := #rem XOR #data[#i];
    FOR #j := 0 TO 7 DO
      IF #rem.%X31 THEN // if leftmost (most significant) bit is set
        #rem := SHR(IN := #rem, N := 1) XOR #POLYNOMIAL;
      ELSE
        #rem := SHR(IN := #rem, N := 1);
      END_IF;
    END_FOR;
  END_FOR;
  #FCCRC32Calc := #rem XOR 16#ffffffff;
END_FUNCTION
```


If the function does not work as expected, it’s often because the endianess is not correct between sender and receiver. Change the `#rem.%X31` bit to `#rem.%X0` to see if it helps.
