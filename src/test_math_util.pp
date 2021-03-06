#!/usr/bin/python3

#include "math.h"
#include "init.h"
#include "test.h"
#include "precision.h"

# The following was calculated by misc/generate_asinh_of_exp_tests.py :
asinh_of_exp_tests = [
  [ 1 , 0.032235378292369784527865848946712188199057140312684 ], # asinh(exp( 1 ))- 1 -ln(2)=...
  [ 6 , 0.0000015360495491554979773791726417095636553617222490443 ], # asinh(exp( 6 ))- 6 -ln(2)=...
  [ 11 , 0.000000000069736702314428308718040371746639796885029839817346 ], # asinh(exp( 11 ))- 11 -ln(2)=...
  [ 16 , 0.0000000000000031660413872735288950531271456171885279637586456956 ], # asinh(exp( 16 ))- 16 -ln(2)=...
  [ 21 , 1.4373805660733899513561857863845093903996543240323e-19 ], # asinh(exp( 21 ))- 21 -ln(2)=...
  [ 26 , 6.5256976741692620117566744046126154463510038869117e-24 ], # asinh(exp( 26 ))- 26 -ln(2)=...
  [ 31 , 2.9626621605849525157126680815586589786020927176369e-28 ], # asinh(exp( 31 ))- 31 -ln(2)=...
  [ 36 , 1.3450465400052846075367888954673816013582613197243e-32 ], # asinh(exp( 36 ))- 36 -ln(2)=...
  [ 41 , 6.1065018443509058234726435961025347510901368590978e-37 ], # asinh(exp( 41 ))- 41 -ln(2)=...
  [ 46 , 2.7723475477407621994868503415523225432864414014397e-41 ], # asinh(exp( 46 ))- 46 -ln(2)=...
  [ 51 , 1.2586730574825222807565552060615451795219859983619e-45 ], # asinh(exp( 51 ))- 51 -ln(2)=...
  [ 56 , 3.6082323586244641222897242306545005364005157881418e-50 ] # asinh(exp( 56 ))- 56 -ln(2)=...
]

for t in asinh_of_exp_tests:
  u,v = t
  y = asinh_of_exp(u)
  yy = v+u+log(2.0)
  test.assert_rel_equal_eps(y,yy,EPS*2)


if False:
  u = 18.0
  y = asinh_of_exp(u)
  yy = 18.693147180559945367405302877547406231957565357996
  test.assert_rel_equal(y,yy)

if False:
  u = 1.0
  for i in range(90):
    y = asinh_of_exp(u)
    if verbosity>=3: PRINT("====== testing asinh_of_exp, u=",u,", y=",y)
    test.assert_rel_equal_eps(sinh(y),exp(u),1.0e-6)
    u = u*2.5 # a little less than e, to try to work out all possible whole-number parts of ln(u)

done(verbosity,"test_math_util")
