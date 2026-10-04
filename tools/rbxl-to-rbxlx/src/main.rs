// Converts a binary Roblox place (.rbxl) into the readable XML format (.rbxlx).
// Usage: cargo run --release -- game.rbxl out.rbxlx
use std::{fs::File, io::{BufReader, BufWriter}};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: rbxl-to-rbxlx <input.rbxl> <output.rbxlx>");
        std::process::exit(1);
    }
    let dom = rbx_binary::from_reader(BufReader::new(File::open(&args[1]).unwrap())).unwrap();
    let root = dom.root().children().to_vec();
    rbx_xml::to_writer_default(BufWriter::new(File::create(&args[2]).unwrap()), &dom, &root).unwrap();
}
