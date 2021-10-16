sudoku: src/sudoku.vala
	valac --pkg=gtk+-3.0 --pkg=posix $^ -o aho-sudoku
