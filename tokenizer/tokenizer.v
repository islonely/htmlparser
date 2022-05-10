module tokenizer

import strings

const whitespace = [rune(`\t`), `\n`, `\f`, ` `]
const null = rune(0)
const ascii_upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
const ascii_lower = 'abcdefghijklmnopqrstuvwxyz'.runes()

enum TokenizerState {
	@none
	data
	rcdata
	rawtext
	script_data
	plaintext
	tag_open
	end_tag_open
	tag_name
	rcdata_lt_sign
	rcdata_end_tag_open
	rcdata_end_tag_name
	rawtext_lt_sign
	rawtext_end_tag_open
	rawtext_end_tag_name
	script_data_lt_sign
	script_data_end_tag_open
	script_data_escape_start
	script_data_escape_start_dash
	script_data_escaped
	script_data_escaped_dash
	script_data_escaped_dash_dash
	script_data_escaped_lt_sign
	script_data_escaped_end_tag_open
	script_data_escaped_end_tag_name
	script_data_double_escape_start
	script_data_double_escaped_dash
	script_data_double_escaped_dash_dash
	script_data_double_escaped_lt_sign
	script_data_double_escape_end
	before_attr_name
	attr_name
	after_attr_name
	before_attr_value
	attr_value_dbl_quoted
	attr_value_sgl_quoted
	attr_value_unquoted
	after_attr_value_quoted
	self_closing_start_tag
	bogus_comment
	markup_declaration_open
	comment_start
	comment_start_dash
	comment
	comment_lt_sign
	comment_lt_sign_bang
	comment_lt_sign_bang_dash
	comment_lt_sign_bang_dash_dash
	comment_end_dash
	comment_end
	comment_end_bang
	doctype
	before_doctype_name
	doctype_name
	after_doctype_name
	after_doctype_pulic_keyword
	before_doctype_public_identifier
	doctype_public_identifier_dbl_quoted
	doctype_public_identifier_sgl_quoted
	after_doctype_public_identifier
	between_doctype_public_and_system_identifiers
	after_doctype_system_keyword
	before_doctype_system_identifier
	doctype_system_identifier_dbl_quoted
	doctype_system_identifier_sgl_quoted
	after_doctype_system_identifier
	bogus_doctype
	cdata_section
	cdata_section_bracket
	cdata_section_end
	char_reference
	named_char_reference
	ambiguous_ampersand
	num_char_reference
	hex_char_reference_start
	decimal_char_reference_start
	hex_char_reference
	decimal_char_reference
	num_char_reference_end
}

struct Tokenizer {
	input []rune
mut:
	return_state TokenizerState = .@none
	state TokenizerState = .data
	cursor int

	curr_input_char rune
	next_input_char rune

	curr_token Token = EOFToken{}
}

fn exit_state_not_implemented(state TokenizerState) {
	println('fn do_state_${state} not implemented. Exiting...')
	exit(1)
}

pub fn new(html []rune) Tokenizer {
	return Tokenizer{
		input: html
	}
}

// gets the next value in buffer and moves the cursor forward once
fn (mut t Tokenizer) next_codepoint() ?rune {
	if t.cursor >= t.input.len {
		return error('End of file.')
	}

	t.cursor++
	return t.input[t.cursor-1]?
}

// gets the next value in buffer
fn (t &Tokenizer) peek_codepoint(offset int) ?rune {
	if t.cursor+offset >= t.input.len {
		return error('End of file.')
	}
	return t.input[t.cursor+offset]
}

[params]
struct SwitchStateParams {
	reconsume bool
}

// saves the current state, changes the state, consumes the next
// character, and invokes the next do_state function.
fn (mut t Tokenizer) switch_state(state TokenizerState, params SwitchStateParams) {
	t.return_state = t.state
	t.state = state

	if !params.reconsume {
		t.curr_input_char = t.next_codepoint() or {
			println(err.msg())
			t.state = .@none
			0
		}
	}
	t.do_state(t.state)
}

// checks if the next characters match `look_for` and moves the cursor
// forward `look_for.len`. Returns none if next characters do not
// match `look_for`.
fn (mut t Tokenizer) look_ahead(look_for string) ? {
	tmp := look_for.runes()
	for i in 0..look_for.len {
		if x := t.peek_codepoint(i) {
			if x != tmp[i] {
				return
			}
		} else {
			return
		}
	}
	t.cursor += look_for.len
}

pub fn (mut t Tokenizer) run() {
	t.curr_input_char = t.next_codepoint() or {
		println('Cannot tokenize empty array.')
		return
	}
	t.do_state(t.state)
}

fn (mut t Tokenizer) do_state(state TokenizerState) {
	match t.state {
		.data { t.do_state_data() }
		.char_reference { t.do_state_char_reference() }
		else { exit_state_not_implemented(t.state) }
	}
}

fn (mut t Tokenizer) do_state_data() {
	match t.curr_input_char {
		`&` {
			t.switch_state(.char_reference)
		}
		`<` {
			t.switch_state(.tag_open)
		}
		null {
			
		}
		else {

		}
	}
}

fn (mut t Tokenizer) do_state_char_reference() {
	exit_state_not_implemented(.char_reference)
}

fn (mut t Tokenizer) do_state_tag_open() {
	if t.curr_input_char == `!` {
		t.switch_state(.markup_declaration_open)
	}
}

fn (mut t Tokenizer) do_state_markup_declaration_open() {
	if _ := t.look_ahead('DOCTYPE') {
		t.switch_state(.doctype)
	} else if _ := t.look_ahead('--') {
		t.switch_state(.comment_start)
	} else if _ := t.look_ahead('[CDATA[') {
		t.switch_state(.cdata_section)
	} else {
		println('Parse Error: Tag cannot open with \'<!\' unless the following characters are \'DOCTYPE\', \'--\', or \'[CDATA[\'.')
		t.switch_state(.bogus_comment)
	}
}

fn (mut t Tokenizer) do_state_doctype() {
	// in properly formatted html, whitespace is required here
	// so we'll use likely for optimization
	if _likely_(t.curr_input_char in whitespace) {
		t.switch_state(.before_doctype_name)
	} else if t.curr_input_char == `>` {
		t.switch_state(.before_doctype_name, reconsume: true)
	}
}

fn (mut t Tokenizer) do_state_before_doctype_name() {
	t.curr_token = DoctypeToken{}
	for {
		if t.state == .@none {
			mut token := t.curr_token as DoctypeToken
			token.force_quirks = true
			eof := EOFToken{}

			break
		} if t.curr_input_char in ascii_upper {

			break
		} else if _unlikely_(t.curr_input_char == null) {

			break
		} else if _unlikely_(t.curr_input_char == `>`) {

			break
		} else if t.curr_input_char in whitespace {
			
		} else {
			mut token := t.curr_token as DoctypeToken
			token.name = t.curr_input_char.str()
			t.switch_state(.doctype_name)

			break
		}
		
		t.curr_input_char = t.next_codepoint() or {
			println(err.msg())
			t.state = .@none
			break
		}
	}
}

fn (mut t Tokenizer) do_state_doctype_name() {
	
}