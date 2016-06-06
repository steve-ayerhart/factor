! Copyright (C) 2008 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel math money ;
in: taxes.usa.medicare

! No base rate for medicare; all wages subject
: medicare-tax-rate ( -- x ) decimal: .0145 ; inline
: medicare-tax ( salary w4 -- x ) drop medicare-tax-rate * ;
