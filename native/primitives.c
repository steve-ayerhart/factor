#include "factor.h"

XT primitives[] = {
	undefined,
	docol,
	dosym,
	primitive_execute,
	primitive_call,
	primitive_ifte,
	primitive_cons,
	primitive_car,
	primitive_cdr,
	primitive_vector,
	primitive_vector_length,
	primitive_set_vector_length,
	primitive_vector_nth,
	primitive_set_vector_nth,
	primitive_string_length,
	primitive_string_nth,
	primitive_string_compare,
	primitive_string_eq,
	primitive_string_hashcode,
	primitive_index_of,
	primitive_substring,
	primitive_string_reverse,
	primitive_sbuf,
	primitive_sbuf_length,
	primitive_set_sbuf_length,
	primitive_sbuf_nth,
	primitive_set_sbuf_nth,
	primitive_sbuf_append,
	primitive_sbuf_to_string,
	primitive_sbuf_reverse,
	primitive_sbuf_clone,
	primitive_sbuf_eq,
	primitive_sbuf_hashcode,
	primitive_arithmetic_type,
	primitive_numberp,
	primitive_to_fixnum,
	primitive_to_bignum,
	primitive_to_float,
	primitive_numerator,
	primitive_denominator,
	primitive_from_fraction,
	primitive_str_to_float,
	primitive_float_to_str,
	primitive_float_to_bits,
	primitive_real,
	primitive_imaginary,
	primitive_from_rect,
	primitive_fixnum_eq,
	primitive_fixnum_add,
	primitive_fixnum_subtract,
	primitive_fixnum_multiply,
	primitive_fixnum_divint,
	primitive_fixnum_divfloat,
	primitive_fixnum_mod,
	primitive_fixnum_divmod,
	primitive_fixnum_and,
	primitive_fixnum_or,
	primitive_fixnum_xor,
	primitive_fixnum_not,
	primitive_fixnum_shift,
	primitive_fixnum_less,
	primitive_fixnum_lesseq,
	primitive_fixnum_greater,
	primitive_fixnum_greatereq,
	primitive_bignum_eq,
	primitive_bignum_add,
	primitive_bignum_subtract,
	primitive_bignum_multiply,
	primitive_bignum_divint,
	primitive_bignum_divfloat,
	primitive_bignum_mod,
	primitive_bignum_divmod,
	primitive_bignum_and,
	primitive_bignum_or,
	primitive_bignum_xor,
	primitive_bignum_not,
	primitive_bignum_shift,
	primitive_bignum_less,
	primitive_bignum_lesseq,
	primitive_bignum_greater,
	primitive_bignum_greatereq,
	primitive_float_eq,
	primitive_float_add,
	primitive_float_subtract,
	primitive_float_multiply,
	primitive_float_divfloat,
	primitive_float_less,
	primitive_float_lesseq,
	primitive_float_greater,
	primitive_float_greatereq,
	primitive_facos,
	primitive_fasin,
	primitive_fatan,
        primitive_fatan2,
        primitive_fcos,
        primitive_fexp,
        primitive_fcosh,
        primitive_flog,
        primitive_fpow,
        primitive_fsin,
        primitive_fsinh,
        primitive_fsqrt,
	primitive_word,
	primitive_word_hashcode,
	primitive_word_xt,
	primitive_set_word_xt,
	primitive_word_primitive,
	primitive_set_word_primitive,
	primitive_word_parameter,
	primitive_set_word_parameter,
	primitive_word_plist,
	primitive_set_word_plist,
	primitive_call_profiling,
	primitive_word_call_count,
	primitive_set_word_call_count,
	primitive_allot_profiling,
	primitive_word_allot_count,
	primitive_set_word_allot_count,
	primitive_word_compiledp,
	primitive_drop,
	primitive_dup,
	primitive_swap,
	primitive_over,
	primitive_pick,
	primitive_to_r,
	primitive_from_r,
	primitive_eq,
	primitive_getenv,
	primitive_setenv,
	primitive_open_file,
	primitive_stat,
	primitive_read_dir,
	primitive_gc,
	primitive_gc_time,
	primitive_save_image,
	primitive_datastack,
	primitive_callstack,
	primitive_set_datastack,
	primitive_set_callstack,
	primitive_exit,
	primitive_client_socket,
	primitive_server_socket,
	primitive_close,
	primitive_add_accept_io_task,
	primitive_accept_fd,
	primitive_can_read_line,
	primitive_add_read_line_io_task,
	primitive_read_line_8,
	primitive_can_read_count,
	primitive_add_read_count_io_task,
	primitive_read_count_8,
	primitive_can_write,
	primitive_add_write_io_task,
	primitive_write_8,
	primitive_add_copy_io_task,
	primitive_pending_io_error,
	primitive_next_io_task,
	primitive_room,
	primitive_os_env,
	primitive_millis,
	primitive_init_random,
	primitive_random_int,
	primitive_type,
	primitive_size,
	primitive_cwd,
	primitive_cd,
	primitive_compiled_offset,
	primitive_set_compiled_offset,
	primitive_set_compiled_cell,
	primitive_set_compiled_byte,
	primitive_literal_top,
	primitive_set_literal_top,
	primitive_address,
	primitive_dlopen,
	primitive_dlsym,
	primitive_dlsym_self,
	primitive_dlclose,
	primitive_alien,
	primitive_local_alien,
	primitive_alien_cell,
	primitive_set_alien_cell,
	primitive_alien_4,
	primitive_set_alien_4,
	primitive_alien_2,
	primitive_set_alien_2,
	primitive_alien_1,
	primitive_set_alien_1,
	primitive_heap_stats,
	primitive_throw,
	primitive_string_to_memory,
	primitive_memory_to_string,
	primitive_local_alienp,
	primitive_alien_address,
};

CELL primitive_to_xt(CELL primitive)
{
	if(primitive < 0 || primitive >= PRIMITIVE_COUNT)
		return (CELL)undefined;
	else
		return (CELL)primitives[primitive];
}
