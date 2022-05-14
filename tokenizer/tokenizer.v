module tokenizer

import datatypes { Stack }
import strings

const (
	whitespace        = [rune(`\t`), `\n`, `\f`, ` `]
	null              = rune(0)
	replacement_token = CharacterToken{
		data: 0xfffd
	}

	ascii_upper        = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
	ascii_lower        = 'abcdefghijklmnopqrstuvwxyz'.runes()
	ascii_numeric      = '123455678890'.runes()
	ascii_alpha        = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.runes()
	ascii_alphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.runes()
)

enum TokenizerState {
	@none
	after_attr_name
	after_attr_value_quoted
	after_doctype_name
	after_doctype_public_identifier
	after_doctype_public_keyword
	after_doctype_system_identifier
	after_doctype_system_keyword
	ambiguous_ampersand
	attr_name
	attr_value_dbl_quoted
	attr_value_sgl_quoted
	attr_value_unquoted
	before_attr_name
	before_attr_value
	before_doctype_name
	before_doctype_public_identifier
	between_doctype_public_and_system_identifiers
	before_doctype_system_identifier
	bogus_comment
	bogus_doctype
	cdata_section
	cdata_section_bracket
	cdata_section_end
	char_reference
	comment
	comment_end
	comment_end_bang
	comment_end_dash
	comment_lt_sign
	comment_lt_sign_bang
	comment_lt_sign_bang_dash
	comment_lt_sign_bang_dash_dash
	comment_start
	comment_start_dash
	data
	decimal_char_reference
	decimal_char_reference_start
	doctype
	doctype_name
	doctype_public_identifier_dbl_quoted
	doctype_public_identifier_sgl_quoted
	doctype_system_identifier_dbl_quoted
	doctype_system_identifier_sgl_quoted
	end_tag_open
	eof
	hex_char_reference
	hex_char_reference_start
	markup_declaration_open
	named_char_reference
	num_char_reference
	num_char_reference_end
	plaintext
	rawtext
	rawtext_end_tag_name
	rawtext_end_tag_open
	rawtext_lt_sign
	rcdata
	rcdata_end_tag_name
	rcdata_end_tag_open
	rcdata_lt_sign
	self_closing_start_tag
	script_data
	script_data_double_escape_end
	script_data_double_escape_start
	script_data_double_escaped_dash
	script_data_double_escaped_dash_dash
	script_data_double_escaped_lt_sign
	script_data_end_tag_open
	script_data_escape_start
	script_data_escape_start_dash
	script_data_escaped
	script_data_escaped_dash
	script_data_escaped_dash_dash
	script_data_escaped_end_tag_open
	script_data_escaped_end_tag_name
	script_data_escaped_lt_sign
	script_data_lt_sign
	tag_name
	tag_open
}

struct Tokenizer {
mut:
	return_state Stack<TokenizerState>
	state        TokenizerState = .data

	cursor    int
	curr_char rune

	curr_token Token = EOFToken{}
	open_tags  Stack<TagToken>

	bldr strings.Builder
pub mut:
	input  []rune
	tokens []Token
}

fn exit_state_not_implemented(state TokenizerState) {
	println('fn do_state_$state not implemented. Exiting...')
	exit(1)
}

pub fn new() Tokenizer {
	return Tokenizer{}
}

// gets the next value in buffer and moves the cursor forward once
fn (mut t Tokenizer) next_codepoint() ?rune {
	if t.cursor >= t.input.len {
		t.state = .eof
		return error('End of file.')
	}

	t.cursor++
	return t.input[t.cursor - 1]
}

// gets the next value in buffer
fn (t &Tokenizer) peek_codepoint(offset int) ?rune {
	if t.cursor + offset >= t.input.len {
		return error('End of file.')
	}
	return t.input[t.cursor + offset]
}

// [inline]
// fn (mut t Tokenizer) propagate(callback fn (mut Tokenizer)) {
// 	t.curr_char = t.next_codepoint() or {
// 		callback(mut t)
// 		return
// 	}
// }

[params]
struct SwitchStateParams {
	return_to TokenizerState = .@none
	reconsume bool
}

// saves the current state, changes the state, consumes the next
// character, and invokes the next do_state function.
fn (mut t Tokenizer) switch_state(state TokenizerState, params SwitchStateParams) {
	t.state = state

	if params.reconsume {
		t.cursor--
	}

	match t.state {
		.after_attr_name { t.do_state_after_attr_name() }
		.after_attr_value_quoted { t.do_state_after_attr_value_quoted() }
		.after_doctype_name { t.do_state_after_doctype_name() }
		.after_doctype_public_identifier { t.do_state_after_doctype_public_identifier() }
		.after_doctype_public_keyword { t.do_state_after_doctype_public_keyword() }
		.after_doctype_system_identifier { t.do_state_after_doctype_system_identifier() }
		.after_doctype_system_keyword { t.do_state_after_doctype_system_keyword() }
		.ambiguous_ampersand { t.do_state_ambiguous_ampersand() }
		.attr_name { t.do_state_attr_name() }
		.attr_value_dbl_quoted { t.do_state_attr_value_dbl_quoted() }
		.attr_value_sgl_quoted { t.do_state_attr_value_sgl_quoted() }
		.attr_value_unquoted { t.do_state_attr_value_unquoted() }
		.before_attr_name { t.do_state_before_attr_name() }
		.before_attr_value { t.do_state_before_attr_value() }
		.before_doctype_name { t.do_state_before_doctype_name() }
		.before_doctype_public_identifier { t.do_state_before_doctype_public_identifier() }
		.between_doctype_public_and_system_identifiers { t.do_state_between_doctype_public_and_system_identifiers() }
		.before_doctype_system_identifier { t.do_state_before_doctype_system_identifier() }
		.bogus_comment { t.do_state_bogus_comment() }
		.bogus_doctype { t.do_state_bogus_doctype() }
		.cdata_section { t.do_state_cdata_section() }
		.cdata_section_bracket { t.do_state_cdata_section_bracket() }
		.cdata_section_end { t.do_state_cdata_section_end() }
		.char_reference { t.do_state_char_reference() }
		.comment { t.do_state_comment() }
		.comment_end { t.do_state_comment_end() }
		.comment_end_bang { t.do_state_comment_end_bang() }
		.comment_end_dash { t.do_state_comment_end_dash() }
		.comment_lt_sign { t.do_state_comment_lt_sign() }
		.comment_lt_sign_bang { t.do_state_comment_lt_sign_bang() }
		.comment_lt_sign_bang_dash { t.do_state_comment_lt_sign_bang_dash() }
		.comment_lt_sign_bang_dash_dash { t.do_state_comment_lt_sign_bang_dash_dash() }
		.comment_start { t.do_state_comment_start() }
		.comment_start_dash { t.do_state_comment_start_dash() }
		.data { t.do_state_data() }
		.decimal_char_reference { t.do_state_decimal_char_reference() }
		.decimal_char_reference_start { t.do_state_decimal_char_reference_start() }
		.doctype { t.do_state_doctype() }
		.doctype_name { t.do_state_doctype_name() }
		.doctype_public_identifier_dbl_quoted { t.do_state_doctype_public_identifier_dbl_quoted() }
		.doctype_public_identifier_sgl_quoted { t.do_state_doctype_public_identifier_sgl_quoted() }
		.doctype_system_identifier_dbl_quoted { t.do_state_doctype_system_identifier_dbl_quoted() }
		.doctype_system_identifier_sgl_quoted { t.do_state_doctype_system_identifier_sgl_quoted() }
		.end_tag_open { t.do_state_end_tag_open() }
		.eof { t.do_state_eof() }
		.hex_char_reference { t.do_state_hex_char_reference() }
		.hex_char_reference_start { t.do_state_hex_char_reference_start() }
		.markup_declaration_open { t.do_state_markup_declaration_open() }
		.named_char_reference { t.do_state_named_char_reference() }
		.num_char_reference { t.do_state_num_char_reference() }
		.num_char_reference_end { t.do_state_num_char_reference_end() }
		.plaintext { t.do_state_plaintext() }
		.rawtext { t.do_state_rawtext() }
		.rawtext_end_tag_name { t.do_state_rawtext_end_tag_name() }
		.rawtext_end_tag_open { t.do_state_rawtext_end_tag_open() }
		.rawtext_lt_sign { t.do_state_rawtext_lt_sign() }
		.rcdata { t.do_state_rcdata() }
		.rcdata_end_tag_name { t.do_state_rcdata_end_tag_name() }
		.rcdata_end_tag_open { t.do_state_rcdata_end_tag_open() }
		.rcdata_lt_sign { t.do_state_rcdata_lt_sign() }
		.self_closing_start_tag { t.do_state_self_closing_start_tag() }
		.script_data { t.do_state_script_data() }
		.script_data_double_escape_end { t.do_state_script_data_double_escape_end() }
		.script_data_double_escape_start { t.do_state_script_data_double_escape_start() }
		.script_data_double_escaped_dash { t.do_state_script_data_double_escaped_dash() }
		.script_data_double_escaped_dash_dash { t.do_state_script_data_double_escaped_dash_dash() }
		.script_data_double_escaped_lt_sign { t.do_state_script_data_double_escaped_lt_sign() }
		.script_data_end_tag_open { t.do_state_script_data_end_tag_open() }
		.script_data_escape_start { t.do_state_script_data_escape_start() }
		.script_data_escape_start_dash { t.do_state_script_data_escape_start_dash() }
		.script_data_escaped { t.do_state_script_data_escaped() }
		.script_data_escaped_dash { t.do_state_script_data_escaped_dash() }
		.script_data_escaped_dash_dash { t.do_state_script_data_escaped_dash_dash() }
		.script_data_escaped_end_tag_open { t.do_state_script_data_escaped_end_tag_open() }
		.script_data_escaped_end_tag_name { t.do_state_script_data_escaped_end_tag_name() }
		.script_data_escaped_lt_sign { t.do_state_script_data_escaped_lt_sign() }
		.script_data_lt_sign { t.do_state_script_data_lt_sign() }
		.tag_name { t.do_state_tag_name() }
		.tag_open { t.do_state_tag_open() }
		else { exit_state_not_implemented(t.state) }
	}

	if params.return_to != .@none {
		t.switch_state(params.return_to)
	}
}

[params]
struct LookAheadParams {
	case_sensitive bool = true
}

// checks if the next characters match `look_for` and moves the cursor
// forward `look_for.len`. Returns none if next characters do not
// match `look_for`.
fn (mut t Tokenizer) look_ahead(look_for string, params LookAheadParams) ?bool {
	tmp := look_for.runes()
	for i in 0 .. look_for.len {
		if x := t.peek_codepoint(i) {
			if params.case_sensitive {
				if x != tmp[i] {
					return none
				}
			} else {
				if rune_to_lower(x) != rune_to_lower(tmp[i]) {
					return none
				}
			}
		} else {
			return none
		}
	}
	t.cursor += look_for.len
	return true
}

[inline]
fn (mut t Tokenizer) push_token(tok Token) {
	t.tokens << tok
}

[inline]
fn (mut t Tokenizer) push_char() {
	t.push_rune(t.curr_char)
}

[inline]
fn (mut t Tokenizer) push_rune(r rune) {
	t.push_token(CharacterToken{ data: r })
}

[inline]
fn (mut t Tokenizer) push_string(str string) {
	for r in str.runes() {
		t.push_rune(r)
	}
}

[inline]
fn (mut t Tokenizer) push_eof(tok EOFToken) {
	t.push_token(tok)
}

pub fn (mut t Tokenizer) run(html []rune) {
	t.input = html
	for t.state != .eof {
		t.switch_state(.data)
	}
}

[inline]
fn (t &Tokenizer) do_state_eof() {
	println('End of file.')
}

fn (t &Tokenizer) parse_error(typ ParseError) {
	println('Parse Error: $typ')
}

// functions for each state organized how they appear here
// https://html.spec.whatwg.org/multipage/parsing.html

// 13.2.5.1
fn (mut t Tokenizer) do_state_data() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .data)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.tag_open)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_char()
		t.switch_state(.data)
		return
	}

	t.push_char()
}

// 13.2.5.2
fn (mut t Tokenizer) do_state_rcdata() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == `&` {
		t.switch_state(.char_reference, return_to: .rcdata)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.rcdata_lt_sign)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.rcdata)
		return
	}

	t.push_char()
}

// 13.2.5.3
fn (mut t Tokenizer) do_state_rawtext() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.rawtext)
		return
	}

	t.push_char()
}

// 13.2.5.4
fn (mut t Tokenizer) do_state_script_data() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_lt_sign)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data)
		return
	}

	t.push_char()
}

// 13.2.5.5
fn (mut t Tokenizer) do_state_plaintext() {
	t.curr_char = t.next_codepoint() or {
		t.push_eof(EOFToken{})
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.plaintext)
		return
	}

	t.push_char()
}

// 13.2.5.6
fn (mut t Tokenizer) do_state_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_before_tag_name)
		t.push_char()
		t.push_eof(
			name: eof_before_tag_name_name
			msg: eof_before_tag_name_msg
		)
		return
	}

	if t.curr_char == `!` {
		t.switch_state(.markup_declaration_open)
		return
	}

	if t.curr_char == `/` {
		t.switch_state(.end_tag_open)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{}
		t.switch_state(.tag_name, reconsume: true)
		return
	}

	if t.curr_char == `?` {
		t.parse_error(.unexpected_question_mark_instead_of_tag_name)
		t.switch_state(.bogus_comment, reconsume: true)
		return
	}

	t.parse_error(.invalid_first_character_of_tag_name)
	t.push_rune(`<`)
	t.switch_state(.data, reconsume: true)
}

// 13.2.5.7
fn (mut t Tokenizer) do_state_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_before_tag_name)
		t.push_char()
		t.push_eof(
			name: eof_before_tag_name_name
			msg: eof_before_tag_name_msg
		)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			typ: .end_tag
		}
		t.switch_state(.tag_name, reconsume: true)
		return
	}

	if _unlikely_(t.curr_char == `>`) {
		t.parse_error(.missing_end_tag_name)
		t.switch_state(.data)
		return
	}

	t.parse_error(.invalid_first_character_of_tag_name)
	t.curr_token = CommentToken{}
	t.switch_state(.bogus_comment, reconsume: true)
}

// 13.2.5.8
fn (mut t Tokenizer) do_state_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_tag)
		t.push_eof(
			name: eof_in_tag_name
			msg: eof_in_tag_msg
		)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		t.switch_state(.before_attr_name)
		return
	}

	if t.curr_char == `/` {
		t.switch_state(.self_closing_start_tag)
		return
	}

	if t.curr_char == `>` {
		t.push_token(t.curr_token)
		if (t.curr_token as TagToken).typ == .start_tag {
			t.open_tags.push(t.curr_token)
		}
		t.switch_state(.data)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.tag_name)
		return
	}

	mut tok := t.curr_token as TagToken
	tok.name += rune_to_lower(t.curr_char).str()
	t.curr_token = tok
}

// 13.2.5.9
fn (mut t Tokenizer) do_state_rcdata_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.rcdata, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.rcdata_end_tag_open)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.rcdata, reconsume: true)
}

// 13.2.5.10
fn (mut t Tokenizer) do_state_rcdata_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.rcdata, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			typ: .end_tag
		}
		t.switch_state(.rcdata_end_tag_name, reconsume: true)
	}

	t.push_rune(`<`)
	t.push_token(CharacterToken{ data: `/` })
	t.switch_state(.rcdata, reconsume: true)
}

// 13.2.5.11
fn (mut t Tokenizer) do_state_rcdata_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.rcdata, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rcdata, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rcdata, reconsume: true)
		}
		return
	}

	if t.curr_char == `>` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rcdata, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.rcdata_end_tag_name)
		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.rcdata, reconsume: true)
}

// 13.2.5.12
fn (mut t Tokenizer) do_state_rawtext_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.write_rune(`<`)
		t.switch_state(.rawtext, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.rawtext_end_tag_open)
		return
	}

	t.write_rune(`<`)
	t.switch_state(.rawtext, reconsume: true)
	return
}

// 13.2.5.13
fn (mut t Tokenizer) do_state_rawtext_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.rawtext, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			typ: .end_tag
		}
		t.switch_state(.rawtext_end_tag_name, reconsume: true)
		return
	}

	t.push_string('</')
	t.switch_state(.rawtext, reconsume: true)
}

// 13.2.5.14
fn (mut t Tokenizer) do_state_rawtext_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.rawtext, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rawtext, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rawtext, reconsume: true)
		}
		return
	}

	if t.curr_char == `>` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.rawtext, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.rawtext_end_tag_name)
		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.rawtext, reconsume: true)
}

// 13.2.5.15
fn (mut t Tokenizer) do_state_script_data_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.script_data_end_tag_open)
		return
	}

	if t.curr_char == `!` {
		t.push_string('<!')
		t.switch_state(.script_data_escape_start)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.16
fn (mut t Tokenizer) do_state_script_data_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			typ: .end_tag
		}
		t.switch_state(.script_data_end_tag_name, reconsume: true)
		return
	}

	t.push_string('</')
	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.17
fn (mut t Tokenizer) do_state_script_data_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data, reconsume: true)
		}
		return
	}

	if t.curr_char == `<` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.18
fn (mut t Tokenizer) do_state_script_data_escape_start() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escape_start_dash)
		return
	}

	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.19
fn (mut t Tokenizer) do_state_script_data_escape_start_dash() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_data, reconsume: true)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escape_start_dash_dash)
		return
	}

	t.switch_state(.script_data, reconsume: true)
}

// 13.2.5.20
fn (mut t Tokenizer) do_state_script_data_escaped() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_escaped_lt_sign)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data_escaped)
		return
	}

	t.push_char()
	t.switch_state(.script_data_escaped)
}

// 13.2.5.21
fn (mut t Tokenizer) do_state_script_data_escaped_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash_dash)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_escaped_lt_sign)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data_escaped)
		return
	}

	t.push_char()
	t.switch_state(.script_data_escaped)
}

// 13.2.5.22
fn (mut t Tokenizer) do_state_script_data_escaped_dash_dash() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_escaped_dash_dash)
		return
	}

	if t.curr_char == `<` {
		t.switch_state(.script_data_escaped_lt_sign)
		return
	}

	if t.curr_char == `>` {
		t.push_rune(`>`)
		t.switch_state(.script_data)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		t.switch_state(.script_data)
		return
	}

	t.push_char()
	t.switch_state(.script_data_escaped)
}

// 13.2.5.23
fn (mut t Tokenizer) do_state_escaped_lt_sign() {
	t.curr_char = t.next_codepoint() or {
		t.push_rune(`<`)
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char == `/` {
		t.bldr = strings.new_builder(0)
		t.switch_state(.script_data_escaped_end_tag_open)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.bldr = strings.new_builder(0)
		t.push_rune(`<`)
		t.switch_state(.script_data_double_escape_start)
		return
	}

	t.push_rune(`<`)
	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.24
fn (mut t Tokenizer) do_state_escaped_end_tag_open() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.curr_token = TagToken{
			typ: .end_tag
		}
		t.switch_state(.script_data_escaped_end_tag_name, reconsume: true)
		return
	}

	t.push_string('</')
	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.25
fn (mut t Tokenizer) do_state_script_data_escaped_end_tag_name() {
	t.curr_char = t.next_codepoint() or {
		t.push_string('</')
		t.push_string(t.bldr.str())
		t.switch_state(.script_data_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.before_attr_name)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data_escaped, reconsume: true)
		}
		return
	}

	if t.curr_char == `/` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.switch_state(.self_closing_start_tag)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data_escaped, reconsume: true)
		}
		return
	}

	if t.curr_char == `>` {
		if (t.curr_token as TagToken).is_appropriate(t) {
			t.push_token(t.curr_token)
			t.switch_state(.data)
		} else {
			t.push_string('</')
			t.push_string(t.bldr.str())
			t.switch_state(.script_data_escaped, reconsume: true)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		mut tok := t.curr_token as TagToken
		tok.name += rune_to_lower(t.curr_char).str()
		t.curr_token = tok
		t.bldr.write_rune(t.curr_char)
		t.switch_state(.script_data_escaped_end_tag_name)

		return
	}

	t.push_string('</')
	t.push_string(t.bldr.str())
	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.26
fn (mut t Tokenizer) do_state_script_data_double_escape_start() {
	t.curr_char = t.next_codepoint() or {
		t.switch_state(.script_escaped, reconsume: true)
		return
	}

	if t.curr_char in tokenizer.whitespace || t.curr_char in [`/`, `>`] {
		// after calling strings.Builder.str() it clears the memory at the location
		// where the string was stored, so the Builder needs to be reset
		buf := t.bldr.str()
		t.bldr = strings.new_builder(buf.len)
		t.bldr.write_string(buf)

		if buf == 'script' {
			t.switch_state(.script_data_double_escaped)
		} else {
			t.push_char()
			t.switch_state(.script_data_escaped)
		}
		return
	}

	if t.curr_char in tokenizer.ascii_alpha {
		t.bldr.write_rune(rune_to_lower(t.curr_char))
		t.push_char()
		t.switch_state(.script_data_double_escape_start)
		return
	}

	t.switch_state(.script_data_escaped, reconsume: true)
}

// 13.2.5.27
fn (mut t Tokenizer) do_state_script_data_double_escaped() {
	t.curr_char = t.next_codepoint() or {
		t.parse_error(.eof_in_script_html_comment_like_text)
		t.push_eof(
			name: eof_in_script_html_comment_like_text_name
			msg: eof_in_script_html_comment_like_text_msg
		)
		return
	}

	if t.curr_char == `-` {
		t.push_rune(`-`)
		t.switch_state(.script_data_double_escaped_dash)
		return
	}

	if t.curr_char == `<` {
		t.push_rune(`<`)
		t.switch_state(.script_data_double_escaped_lt_sign)
		return
	}

	if _unlikely_(t.curr_char == tokenizer.null) {
		t.parse_error(.unexpected_null_character)
		t.push_token(tokenizer.replacement_token)
		return
	}

	t.push_char()
	t.switch_state(.script_data_double_escaped)
}
