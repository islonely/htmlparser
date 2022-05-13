module tokenizer

struct Ast {
pub mut:
	tokens []Token
}

pub fn (ast &Ast) len() int {
	return ast.tokens.len
}