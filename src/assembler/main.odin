package main

import "../assembler/syntax"
import "core:fmt"
import "core:os"

read_host_file :: proc(path: string) -> ([]byte, bool) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil do return nil, false
	return data, true
}

fail :: proc(msg: string) {
	fmt.eprintf("Error: %s\n", msg)
	os.exit(1)
}

main :: proc() {
	if len(os.args) < 2 || len(os.args) > 4 {
		fmt.eprintln("Usage: bmasm <input.asm> [-o output.bhm]")
		os.exit(1)
	}
	in_path := os.args[1]
	out_path := "out.bhm"
	if len(os.args) == 4 {
		if os.args[2] != "-o" {
			fmt.eprintln("Usage: bmasm <input.asm> [-o output.bhm]")
			os.exit(1)
		}
		out_path = os.args[3]
	}
	if len(os.args) == 3 {
		fmt.eprintln("Usage: bmasm <input.asm> [-o output.bhm]")
		os.exit(1)
	}

	syntax.init_temp_labels()
	defer syntax.free_temp_labels()
	syntax.init_labels()
	defer syntax.free_labels()
	syntax.init_constants()
	defer syntax.free_constants()
	syntax.init_mnemonics()
	defer syntax.free_mnemonics()
	syntax.FILE_PROVIDER = read_host_file

	data, rerr := os.read_entire_file(in_path, context.allocator)
	if rerr != nil do fail("could not read input file")
	defer delete(data)

	toks, lerr := syntax.tokenize(in_path, string(data))
	if lerr.raised do fail(lerr.msg)
	defer delete(toks)

	lines := syntax.split_lines(toks[:])
	stmts, perr := syntax.parse_into_statements(lines[:])
	delete(lines)
	if perr.raised do fail(perr.msg)

	stack := make([dynamic]string)
	defer delete(stack)
	pool := make([dynamic]syntax.FileBlob)
	defer syntax.free_file_blobs(pool)
	if xerr := syntax.expand_includes(&stmts, in_path, 0, &stack, &pool); xerr.raised do fail(xerr.msg)

	if terr := syntax.resolve_temp_labels(stmts[:]); terr.raised do fail(terr.msg)
	if rerr := syntax.replace_operands(stmts[:]); rerr.raised do fail(rerr.msg)
	if eqerr := syntax.emitter_pass_0(stmts[:]); eqerr.raised do fail(eqerr.msg)
	syntax.substitute_constants(stmts[:])
	for i in 0 ..< len(stmts) {
		d, is_dir := stmts[i].(syntax.Directive)
		if !is_dir do continue
		if verr := syntax.validate_directive_operands(&d); verr.raised do fail(verr.msg)
	}

	e := syntax.Emitter{}
	syntax.emitter_init(&e)
	if aerr := syntax.pass1_size_and_relax(&e, stmts[:]); aerr.raised do fail(aerr.msg)
	if aerr := syntax.pass2_emit(&e, stmts[:]); aerr.raised do fail(aerr.msg)

	if werr := os.write_entire_file(out_path, e.output[:]); werr != nil do fail("could not write output file")
}
