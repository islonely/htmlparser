module tokenizer

struct Ast {
mut:
	tokens []Token
}

pub fn (ast &Ast) len() int {
	return ast.tokens.len
}