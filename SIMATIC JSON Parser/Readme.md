# SIMATIC JSON Parser
**Date:** 2019-04-15, ***updated: 2020-11-23***

JSON is a very powerful and simple way of arranging data and exchange it between systems.

https://www.json.org/

JSON parser comes for almost every PC based programming language, but not PLC’s, so I started my own.

This parser can read and write JSON in Siemens SIMATIC S7-12xx/S7-15xx PLC’s.
There are some limitations though;
* Only strings, numbers and booleans are supported.
* No spaces between characters.

JSON is very useful when systems has to exchange data in e.g. TCP/IP socket communication. Traditionally data exchange has to be documented and agreed on between systems, to have the same data structure for the byte stream. With JSON, this is not needed anymore, and the data and values can be arranged differently but, still understood on all systems.

Internal constants are used to adjust array length, to reduce memory usage;

```pascal
  VAR CONSTANT 
      JSON_DATA_MAX : Int := 10;
      MAX_ARRAY_ELEMENTS : Int := 10000;
   END_VAR
```
