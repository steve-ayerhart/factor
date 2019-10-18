#include "factor.h"

/* FFI calls this */
void box_integer(F_FIXNUM integer)
{
	dpush(tag_integer(integer));
}

/* FFI calls this */
void box_cell(CELL cell)
{
	dpush(tag_cell(cell));
}

/* FFI calls this */
F_FIXNUM unbox_integer(void)
{
	return to_fixnum(dpop());
}

CELL to_cell(CELL x)
{
	F_FIXNUM fixnum;
	F_ARRAY* bignum;

	switch(type_of(x))
	{
	case FIXNUM_TYPE:
		fixnum = untag_fixnum_fast(x);
		if(fixnum < 0)
		{
			range_error(F,0,tag_fixnum(fixnum),FIXNUM_MAX);
			return -1;
		}
		else
			return (CELL)fixnum;
		break;
	case BIGNUM_TYPE:
		bignum = to_bignum(x);
		if(BIGNUM_NEGATIVE_P(bignum))
		{
			range_error(F,0,tag_bignum(bignum),FIXNUM_MAX);
			return -1;
		}
		else
			return s48_bignum_to_long(untag_bignum(x));
	default:
		type_error(BIGNUM_TYPE,x);
		return 0;
	}
}

/* FFI calls this */
CELL unbox_cell(void)
{
	return to_cell(dpop());
}

F_ARRAY* to_bignum(CELL tagged)
{
	F_RATIO* r;
	F_ARRAY* x;
	F_ARRAY* y;
	F_FLOAT* f;

	switch(type_of(tagged))
	{
	case FIXNUM_TYPE:
		return s48_long_to_bignum(untag_fixnum_fast(tagged));
	case BIGNUM_TYPE:
		return (F_ARRAY*)UNTAG(tagged);
	case RATIO_TYPE:
		r = (F_RATIO*)UNTAG(tagged);
		x = to_bignum(r->numerator);
		y = to_bignum(r->denominator);
		return s48_bignum_quotient(x,y);
	case FLOAT_TYPE:
		f = (F_FLOAT*)UNTAG(tagged);
		return s48_double_to_bignum(f->n);
	default:
		type_error(BIGNUM_TYPE,tagged);
		return NULL; /* can't happen */
	}
}

void primitive_to_bignum(void)
{
	maybe_garbage_collection();
	drepl(tag_bignum(to_bignum(dpeek())));
}

void primitive_bignum_eq(void)
{
	F_ARRAY* y = to_bignum(dpop());
	F_ARRAY* x = to_bignum(dpop());
	box_boolean(s48_bignum_equal_p(x,y));
}

#define GC_AND_POP_BIGNUMS(x,y) \
	F_ARRAY *x, *y; \
	maybe_garbage_collection(); \
	y = untag_bignum_fast(dpop()); \
	x = untag_bignum_fast(dpop());

void primitive_bignum_add(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_add(x,y)));
}

void primitive_bignum_subtract(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_subtract(x,y)));
}

void primitive_bignum_multiply(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_multiply(x,y)));
}

void primitive_bignum_divint(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_quotient(x,y)));
}

void primitive_bignum_divfloat(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_float(
		s48_bignum_to_double(x) /
		s48_bignum_to_double(y)));
}

void primitive_bignum_divmod(void)
{
	F_ARRAY *q, *r;
	GC_AND_POP_BIGNUMS(x,y);
	s48_bignum_divide(x,y,&q,&r);
	dpush(tag_bignum(q));
	dpush(tag_bignum(r));
}

void primitive_bignum_mod(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_remainder(x,y)));
}

void primitive_bignum_and(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_bitwise_and(x,y)));
}

void primitive_bignum_or(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_bitwise_ior(x,y)));
}

void primitive_bignum_xor(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_bitwise_xor(x,y)));
}

void primitive_bignum_shift(void)
{
	F_FIXNUM y;
        F_ARRAY* x;
	maybe_garbage_collection();
	y = to_fixnum(dpop());
	x = to_bignum(dpop());
	dpush(tag_bignum(s48_bignum_arithmetic_shift(x,y)));
}

void primitive_bignum_less(void)
{
	F_ARRAY* y = to_bignum(dpop());
	F_ARRAY* x = to_bignum(dpop());
	box_boolean(s48_bignum_compare(x,y) == bignum_comparison_less);
}

void primitive_bignum_lesseq(void)
{
	F_ARRAY* y = to_bignum(dpop());
	F_ARRAY* x = to_bignum(dpop());

	switch(s48_bignum_compare(x,y))
	{
	case bignum_comparison_less:
	case bignum_comparison_equal:
		dpush(T);
		break;
	case bignum_comparison_greater:
		dpush(F);
		break;
	default:
		critical_error("s48_bignum_compare returns bogus value",0);
		break;
	}
}

void primitive_bignum_greater(void)
{
	F_ARRAY* y = to_bignum(dpop());
	F_ARRAY* x = to_bignum(dpop());
	box_boolean(s48_bignum_compare(x,y) == bignum_comparison_greater);
}

void primitive_bignum_greatereq(void)
{
	F_ARRAY* y = to_bignum(dpop());
	F_ARRAY* x = to_bignum(dpop());

	switch(s48_bignum_compare(x,y))
	{
	case bignum_comparison_less:
		dpush(F);
		break;
	case bignum_comparison_equal:
	case bignum_comparison_greater:
		dpush(T);
		break;
	default:
		critical_error("s48_bignum_compare returns bogus value",0);
		break;
	}
}

void primitive_bignum_not(void)
{
	maybe_garbage_collection();
	drepl(tag_bignum(s48_bignum_bitwise_not(
		untag_bignum(dpeek()))));
}

void copy_bignum_constants(void)
{
	COPY_OBJECT(bignum_zero);
	COPY_OBJECT(bignum_pos_one);
	COPY_OBJECT(bignum_neg_one);
}