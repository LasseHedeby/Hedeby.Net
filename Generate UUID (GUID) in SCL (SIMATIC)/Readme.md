# Generate UUID (GUID) in SCL (SIMATIC)
**Date:** 2020-08-21

UUIDv4 based on RFC4122 can be generated in 5 different ways. The 4th is by random or psudo-random generation. This function both generates a GUID based on RFC4122 and also a ShortGUID, where the GUID is encode with Base64 encoding, as described here by [Mads Kristensen](https://www.madskristensen.net/blog/A-shorter-and-URL-friendly-GUID) for C#.

## GUID
```
Field                  Data Type     Octet  Note
	                                    #
	
time_low               unsigned 32   0-3    The low field of the
                        bit integer          timestamp

time_mid               unsigned 16   4-5    The middle field of the
                        bit integer          timestamp

time_hi_and_version    unsigned 16   6-7    The high field of the
                        bit integer          timestamp multiplexed
                                            with the version number

clock_seq_hi_and_rese  unsigned 8    8      The high field of the
rved                   bit integer          clock sequence
                                            multiplexed with the
                                            variant

clock_seq_low          unsigned 8    9      The low field of the
                        bit integer          clock sequence

node                   unsigned 48   10-15  The spatially unique
                        bit integer          node identifier
```

In this example I used a Siemens S7-1200 PLC and used the internal real-time clock. By reading this to the `DTL` data type we get a struct with the different elements. By using the tag NANOSECOND we get a psudo-random number in udint (Unsigned 32-bit integer) format.

To optimize performance this can be used in one scan cycle, by using parts of this udint. E.g. splitting into words and bytes.

```pascal
// Time_low
#tempTimeStatus := RD_SYS_T(#tempTime);
#tempTimeLow := #tempTime.NANOSECOND;

// Time_mid
#tempTimeStatus := RD_SYS_T(#tempTime);
#tempTimeMid := #tempTime.NANOSECOND.%W1;
```

After generating all the fileds, the content of these fields is converted to hexidecimal annotation in ASCII;
```pascal
// Time_low
#tempGUID := '';
#RetVal := HTA(IN := #tempTimeLow, N := 4, OUT => #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := '-');
#RetVal := HTA(IN := #tempTimeMid, N := 2, OUT => #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := '-');
#RetVal := HTA(IN := #tempTimeHiAndVersion, N := 2, OUT => #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := '-');
#RetVal := HTA(IN := #tempClockSeq, N := 2, OUT => #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := #tempConvert);
#tempGUID := CONCAT(IN1 := #tempGUID, IN2 := '-');
FOR #i := 0 TO 5 DO
    #RetVal := HTA(IN := #tempNode[#i], N := 1, OUT => #tempConvert);
    #tempGUID := CONCAT(IN1 := #tempGUID, IN2 := #tempConvert);
END_FOR;
```

The UUID is then converted to lower case;
```pascal
// Convert all charactors to lower case
Strg_TO_Chars(Strg := #tempGUID,
                pChars := 0,
                Cnt => #tempCount,
                Chars := #tempChar);
FOR #i := 0 TO UINT_TO_INT(#tempCount) DO
    CASE BYTE_TO_INT(CHAR_TO_BYTE(#tempChar[#i])) OF
        16#41:  // A
            #tempChar[#i] := 'a';
        16#42:  // B
            #tempChar[#i] := 'b';
        16#43:  // C
            #tempChar[#i] := 'c';
        16#44:  // D
            #tempChar[#i] := 'd';
        16#45:  // E
            #tempChar[#i] := 'e';
        16#46:  // F
            #tempChar[#i] := 'f';
    END_CASE;
END_FOR;
Chars_TO_Strg(Chars := #tempChar,
              pChars := 0,
              Cnt := #tempCount,
              Strg => #tempGUID);
```

This GUID is outputed on the tag `guid`with the format as described in RFC4122 `f81d4fae-7dec-11d0-a765-00a0c91e6bf6`

## Short GUID
**Inspiraton**: https://www.madskristensen.net/blog/A-shorter-and-URL-friendly-GUID

By encoding the UUID with [Base64](https://en.wikipedia.org/wiki/Base64) encoding we can shorten the GUID from 36 to 22 ASCII charactors without loosing the uniqueness and content (it can be decoded again). This is usefull if size is cruisual, like if the content has to be sued in an RFID, DataMatrix or transmitted over low-bandwidth network.

The ShortGUID is outputtet on the tag `shortGUID` with the format `FEx1sZbSD0ugmgMAF_RGHw`

### Example
`540c2d5f-a9ab-4414-bd36-9999f5388773`

`Xy0MVKupFES9NpmZ9TiHcw`
