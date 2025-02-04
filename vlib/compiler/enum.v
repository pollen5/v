// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module compiler

fn (p mut Parser) enum_decl(no_name bool) {
	is_pub := p.tok == .key_pub
	if is_pub {
		p.next()
	}
	p.check(.key_enum)
	p.fspace()
	mut enum_name	:= p.check_name()
	is_c := enum_name == 'C' && p.tok == .dot
	if is_c {
		p.check(.dot)
		enum_name = p.check_name()
	}
	// Specify full type name
	if !p.builtin_mod && p.mod != 'main' {
		enum_name = p.prepend_mod(enum_name)
	}
	// Skip empty enums
	if !no_name && !p.first_pass() {
		p.cgen.typedefs << 'typedef int $enum_name;'
	}
	p.fspace()
	p.check(.lcbr)
	mut val := 0
	mut fields := []string
	for p.tok == .name {
		field := p.check_name()
		if contains_capital(field) {
			p.warn('enum values cannot contain uppercase letters, use snake_case instead')
		}
		fields << field
		p.fgen_nl()
		name := '${mod_gen_name(p.mod)}__${enum_name}_$field'
		if p.tok == .assign {
			mut enum_assign_tidx := p.cur_tok_index()
			if p.peek() == .number {
				p.next()
				val = p.lit.int()
				p.next()
			}else{
				p.next()
				enum_assign_tidx = p.cur_tok_index()
				p.error_with_token_index('only numbers are allowed in enum initializations', enum_assign_tidx)
			}
		}
		if p.pass == .main {
			p.cgen.consts << '#define $name $val'
		}
		if p.tok == .comma {
			p.next()
		}
		val++
	}
	is_flag := p.attr == 'flag'
	if is_flag && fields.len > 32 {
		p.error('when an enum is used as bit field, it must have a max of 32 fields')
	}
	mut T := Type {
		name: enum_name
		mod: p.mod
		parent: 'int'
		cat: .enum_
		enum_vals: fields.clone()
		is_public: is_pub
		is_flag: is_flag
	}
	if is_flag && !p.first_pass() {
		p.gen_enum_flag_methods(mut T)
	}
	p.table.register_type(T)
	p.check(.rcbr)
	p.fgenln('\n')
}

fn (p mut Parser) check_enum_member_access() {
	T := p.find_type(p.expected_type)
	if T.cat == .enum_ {
		p.check(.dot)
		val := p.check_name()
		// Make sure this enum value exists
		if !T.has_enum_val(val) {
			p.error('enum `$T.name` does not have value `$val`')
		}
		p.gen(mod_gen_name(T.mod) + '__' + p.expected_type + '_' + val)
	} else {
		p.error('`$T.name` is not an enum')
	}
}


