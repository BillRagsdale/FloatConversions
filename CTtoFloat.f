\ CTtoFloat-B    \ Metastock to Forth

\ A WFR  Nov. 17, 2023  All working
\ B WFR  Nov. 30, 2023  Updates
((
Glossary:
MS>IEEE ( n -- ) ( fs: -- f ) convert old Microsoft to IEEE float.
IEEE>MS ( f: f -- ) ( -- n ) convert IEEE to old Microsoft.
FS>DS ( fs: f -- ) ( -- n1 n2 ) transfers float f in binary to data stack.
                                n1 is high 32 bits, n2 is low 32 bits.
IEEE>Scaled (fs f -- ) ( n1 -- n2) \ scale f by n1 forming n2
))

anew floater   only forth reset-stacks  decimal
7 set-precision
dup-warning-off
: B. ( n -- ) \ A diagnostic binary print.
    cr ."        3  2    2    2    1    1    0    0    0 "
    cr ."        1  8    4    0    6    2    8    4    0 "
       \         0000 0000 0000 0001 0010 0011 0100 0000
  base @ binary    cr 6 spaces
  swap s>d  <#  8 0 do  # # # # bl hold loop #> type
  base !   ;   dup-warning-on

 \ 0x1234 b.
(( Algorythm
1. If zero, force zero as final float and exit.
2. Copy float image as two 32 bit values on data stack.
3. Shift the low 32 bits, 29 bits to the right filling with zeros.
4. Swap to access high 32 bits.
5. And with 0x7FF00000 to extract exponent.
6. 20 bit right shift to bring exponent for calculation.
7. Subtract 1032 bias add 129 bias.
8. Shift this exponent 24 bits left.
9. Extract sign and shift 8 bits to left.
10. Extract low 20 bits
11. Shift 3 bits left to make room for the low 3 bits.
12. Or in sign, or in low 3 bits.
))

: IEEE>MS ( f: f -- ) ( -- ms_float ) \ 64 bit IEEE to 32 bit MS
   fdup f0= if fdrop 0 exit then
   FS>DS             \ floating to two 32 bit stack values
                     \ with low order byte at top of stack
   29 rshift         \ low 3 bits to left, filling with zero
   swap              \ low3bits high32
   dup 0x7FF00000 and   \ low3bits high32 exponent
\ A trick? shift 894 20 bits up as the bias adjustment.
\ 894 20 lshift -
   20 rshift         \ bring exponent down for adjustment
   1023 - 129 +      \ translate the exponent
   24 lshift         \ move exponent high, low3bits high32 exp
   over 0x80000000 and \ low3bits high32 proto signbit
   8 rshift or       \ low3bit high32 protoWithSign
   swap 0x000FFFFF and \ low3bits proto highsignificand
   3 lshift          \ room in highsignificand for low three bits
   or                \ low3bits sign,exp,highsignificand
   or    ;           \ low3bits included

((

\ Masks for IEEE floats
  0x80000000   (  00000000 ) CONSTANT SignMask
  0x7FF00000   (  00000000 ) CONSTANT ExpMask
  0x000FFFFF   (  FFFFFFFF ) CONSTANT HighSignificand

\ *** Keep this for presentations ***
: IEEE>MS ( f: f -- ) ( -- ms_float ) \ 64 bit IEEE to 32 bit MS
  FS>DS  \ floating single to two 32 bit stack values
\ low order byte at top of stack
\ extracting lower 3 bits
 \ drop E000000  *** just for testing  got low 32 bit TOS
    cr  ." Lower 32 bits " dup b.   \ high32 low32
    29 rshift   \ low 3 bits left, filling with zeros
    cr  ." NowShifted " dup b.  \ high32 final low3bits
    swap                        \ low3bits high32
   cr cr ." Raw high 32 bits  "  dup  b.
   dup expmask and                \ low3bits high32 exponent
      cr ." Exponent   "  dup  b. \ low3bits high32 exponentup
  20 rshift
      cr ." Shifted exp"  dup b.  \ lo3bits high32 exponentlow
   1023 - 129 +                   \ translate the exponent
      cr  ." New exp    "  dup b. \ lo3bits high32 adjexponent
   24 lshift        \ exponent move high, low3bits high32 exp
      cr      ." Exponent placed    " dup b.
      cr 0x84700000 ." want exp " b. \ comprison for good 15 float
    \ have lo32bits high32 proto-float-with-exp
\ now work on sign
     over signmask and \ low3bits high32 proto signbit
      cr ." Sign bit "  dup b.
   8 rshift or
    cr ." Sign positioned " dup b.

 \  now working on significand
   swap highsignificand and \ low3bits proto highsignificand
    cr dup  ." Hi 20 bits of Significand " b.
   3 lshift  \ make room  for low three bits
    cr dup  ." Significand 20 bits placed "  b.
   or  \ low3bits proto
   cr ." sign,exp,low23bits" dup b.
   or  \ low3bits included
   cr ." Final  "  dup b.  ;
))

 \ cr cr .( Start  ) 15e IEEE>MS

(( Algorithm
1. Extract low 23 bits over 0..22.
2. Or in a 1 as the 24th bit at 23.
3. Pass to floating point stack.
4. Shift decimal 23 bits to the left.
   2e 23e f** f/ or 0x800000 or 8388608 decimal.
5. Extract exponent, top 8 bits by 'and' 0xFF000000.
6. Right shift by 24 bits for calculation.
7. Subtract bias of 129.
8. Raise to the power of the float exponent by f**.
9. Extract the sign and apply to the final float.
))

: MS>IEEE  ( n -- ) ( fs: -- n ) \ Micr0soft to IEEE float conversion
  dup ( could do a zero test here )
  0x007FFFFF and 0x00800000 or s>f \ signficand in 24 bits
  8388608e f/          \ floating 23 bit right shift
\ 2e 23e f** f/
  dup 0xFF000000 and 24 rshift 129 -  \ remove offset
  2e s>f f**  f*  \ scale by the float exponent, yet unsigned.
  0x00800000 and if fnegate then  ; \ adjust sign?

\ *** test dual conversion
-1231019e fdup cr f. IEEE>MS  MS>IEEE f.
0x951628A8 MS>IEEE IEEE>MS  MS>IEEE cr f. 0x1230101 h. .( triple)
\
\ Microsoft precision limit 2^23. 8,388,608
2e 23e f** IEEE>MS  MS>IEEE cr f.  2e 23e f** f.
-12.3456e fdup IEEE>MS MS>IEEE cr f. f.
0e fdup IEEE>MS dup cr h. MS>IEEE  f. f.
0x000 dup  MS>IEEE cr f. h.
.000001e fdup IEEE>MS MS>IEEE cr f. f.
-0.12345e fdup IEEE>MS MS>IEEE cr f. f.


0x0        MS>IEEE cr f. .( zero    )
0x83600000 MS>IEEE cr f. .( 7.00    )
0x84700000 MS>IEEE cr f. .( 15.00   )
0x85780000 MS>IEEE cr f. .( 31.00   )
0x951628A8 MS>IEEE cr f. .( 1230101 )

: IEEE>Scaled ( f: f -- ) ( n1 -- n2  ) \ 64 bit IEEE to a scaled integer
\  n1 set the decade scaling of f conveted to interger n2.
\  This could be used for MetaStock data treated as integers.
   10e s>f  f** f*  f>s ;
1234.67e 2 ieee>scaled cr cr .( Scaled see 1234567 )  .

\s
