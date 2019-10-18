typedef struct {
	CELL car;
	CELL cdr;
} F_CONS;

INLINE F_CONS* untag_cons(CELL tagged)
{
	type_check(CONS_TYPE,tagged);
	return (F_CONS*)UNTAG(tagged);
}

INLINE CELL tag_cons(F_CONS* cons)
{
	return RETAG(cons,CONS_TYPE);
}

CELL cons(CELL car, CELL cdr);

void primitive_cons(void);
