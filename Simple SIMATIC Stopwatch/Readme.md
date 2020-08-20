# Simple SIMATIC Stopwatch
**Date:** 2020-01-02

This is a simple way of measuring times in a SIMATIC CPU, down to the nanosecond. It uses the internal system function RUNTIME.

This can be used easily to measure cycletime, takt time, etc. It works like a stopwatch...

* ... when start is True, the timer is running,
* ... when start is False, the timer is not running, and not reset (making it pause),
* ... when reset is True, the timer is reset.

The output is an LReal in milliseconds.

```pascal
FUNCTION_BLOCK "FBStopWatch"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 0.1
   VAR_INPUT 
      enable : Bool;
      start : Bool;
      reset : Bool;
   END_VAR

   VAR_OUTPUT 
      currentTime : LReal;
      lastTime : LReal;
   END_VAR

   VAR 
      statStep : Int;
      statTimePeriod : LReal;
      statTimeStart : LReal;
      statPausePeriodCalc : LReal;
      statPausePeriodMemory : LReal;
      statPausePeriod : LReal;
      statPauseStart : LReal;
   END_VAR

   VAR_TEMP 
      statTimeMemory : LReal;
      statPauseMemory : LReal;
   END_VAR


BEGIN
	IF #reset OR NOT #enable THEN
	    #statStep := 0;
	    #statTimePeriod := 0;
	    #statPausePeriodCalc := 0;
	    #statTimeStart := 0;
	    #statPauseStart := 0;
	    #statPausePeriodMemory := 0;
	    #statPausePeriod := 0;
	    #currentTime := 0;
	    RETURN;
	END_IF;
	IF (#statStep = 0) THEN
	    IF #start THEN
	        #statTimeMemory := 0;
	        #statTimePeriod := RUNTIME(#statTimeMemory);
	        #statTimeStart := #statTimeMemory;
	        #statPauseStart := 0;
	        #statStep := 10;
	    END_IF;
	END_IF;
	IF (#statStep = 10) THEN
	    #statTimeMemory := #statTimeStart;
	    #statTimePeriod := RUNTIME(#statTimeMemory);
	    #currentTime := (#statTimePeriod - #statPausePeriod);
	    #lastTime := #currentTime;
	    IF NOT #start THEN
	        #statPauseMemory := 0;
	        #statPausePeriodCalc := RUNTIME(#statPauseMemory);
	        #statPauseStart := #statPauseMemory;
	        
	        #statStep := 20;
	    END_IF;
	END_IF;
	IF (#statStep = 20) THEN
	    #statPauseMemory := #statPauseStart;
	    #statPausePeriodCalc := RUNTIME(#statPauseMemory);
	    IF #start THEN
	        #statPausePeriodMemory += #statPausePeriodCalc;
	        #statPausePeriodCalc := 0;
	        #statStep := 10;
	    END_IF;
	END_IF;
	#statPausePeriod := #statPausePeriodMemory + #statPausePeriodCalc;
END_FUNCTION_BLOCK
```


