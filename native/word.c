#include "factor.h"

/* When a word is executed we jump to the value of the xt field. However this
   value is an unportable function pointer, so in the image we store a primitive
   number that indexes a list of xts. */
void update_xt(F_WORD* word)
{
	word->xt = primitive_to_xt(to_fixnum(word->primitive));
}

/* <word> ( name vocabulary -- word ) */
void primitive_word(void)
{
	F_WORD *word;
	CELL name, vocabulary;

	maybe_gc(sizeof(F_WORD));

	vocabulary = dpop();
	name = dpop();
	word = allot_object(WORD_TYPE,sizeof(F_WORD));
	word->hashcode = tag_fixnum((CELL)word); /* initial address */
	word->name = name;
	word->vocabulary = vocabulary;
	word->primitive = tag_fixnum(0);
	word->def = F;
	word->props = F;
	word->xt = (CELL)undefined;
	dpush(tag_word(word));
}

void primitive_update_xt(void)
{
	update_xt(untag_word(dpop()));
}

void primitive_word_compiledp(void)
{
	F_WORD* word = untag_word(dpop());
	box_boolean(word->xt != (CELL)docol && word->xt != (CELL)dosym);
}

void fixup_word(F_WORD* word)
{
	data_fixup(&word->primitive);

	/* If this is a compiled word, relocate the code pointer. Otherwise,
	reset it based on the primitive number of the word. */
	if(word->xt >= code_relocation_base
		&& word->xt < code_relocation_base
		- compiling.base + compiling.limit)
		code_fixup(&word->xt);
	else
		update_xt(word);

	data_fixup(&word->name);
	data_fixup(&word->vocabulary);
	data_fixup(&word->def);
	data_fixup(&word->props);
}

void collect_word(F_WORD* word)
{
	copy_handle(&word->name);
	copy_handle(&word->vocabulary);
	copy_handle(&word->def);
	copy_handle(&word->props);
}
