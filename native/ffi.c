#include "factor.h"

DLL* untag_dll(CELL tagged)
{
	DLL* dll = (DLL*)UNTAG(tagged);
	type_check(DLL_TYPE,tagged);
	if(dll->dll == NULL)
		general_error(ERROR_EXPIRED,tagged);
	return (DLL*)UNTAG(tagged);
}

CELL unbox_alien(void)
{
	return untag_alien(dpop())->ptr;
}

void box_alien(CELL ptr)
{
	ALIEN* alien = allot_object(ALIEN_TYPE,sizeof(ALIEN));
	alien->ptr = ptr;
	alien->local = false;
	dpush(tag_object(alien));
}

INLINE CELL alien_pointer(void)
{
	F_FIXNUM offset = unbox_integer();
	ALIEN* alien = untag_alien(dpop());
	CELL ptr = alien->ptr;

	if(ptr == NULL)
		general_error(ERROR_EXPIRED,tag_object(alien));

	return ptr + offset;
}

void primitive_alien(void)
{
	CELL ptr = unbox_integer();
	maybe_garbage_collection();
	box_alien(ptr);
}

void primitive_local_alien(void)
{
	CELL length = unbox_integer();
	ALIEN* alien;
	F_STRING* local;
	maybe_garbage_collection();
	alien = allot_object(ALIEN_TYPE,sizeof(ALIEN));
	local = string(length / CHARS,'\0');
	alien->ptr = (CELL)local + sizeof(F_STRING);
	alien->local = true;
	dpush(tag_object(alien));
}

void primitive_local_alienp(void)
{
	box_boolean(untag_alien(dpop())->local);
}

void primitive_alien_address(void)
{
	box_cell(untag_alien(dpop())->ptr);
}

void primitive_alien_cell(void)
{
	box_integer(get(alien_pointer()));
}

void primitive_set_alien_cell(void)
{
	CELL ptr = alien_pointer();
	CELL value = unbox_integer();
	put(ptr,value);
}

void primitive_alien_4(void)
{
	CELL ptr = alien_pointer();
	box_integer(*(int*)ptr);
}

void primitive_set_alien_4(void)
{
	CELL ptr = alien_pointer();
	CELL value = unbox_integer();
	*(int*)ptr = value;
}

void primitive_alien_2(void)
{
	CELL ptr = alien_pointer();
	box_signed_2(*(uint16_t*)ptr);
}

void primitive_set_alien_2(void)
{
	CELL ptr = alien_pointer();
	CELL value = unbox_signed_2();
	*(uint16_t*)ptr = value;
}

void primitive_alien_1(void)
{
	box_signed_1(bget(alien_pointer()));
}

void primitive_set_alien_1(void)
{
	CELL ptr = alien_pointer();
	BYTE value = value = unbox_signed_1();
	bput(ptr,value);
}

void fixup_dll(DLL* dll)
{
	dll->dll = NULL;
}

void fixup_alien(ALIEN* alien)
{
	alien->ptr = NULL;
}

void collect_alien(ALIEN* alien)
{
	if(alien->local && alien->ptr != NULL)
	{
		F_STRING* ptr = (F_STRING*)(alien->ptr - sizeof(F_STRING));
		ptr = copy_untagged_object(ptr,SSIZE(ptr));
		alien->ptr = (CELL)ptr + sizeof(F_STRING);
	}
}
