sudoku: src/sudoku.vala
	valac --pkg=gtk+-3.0 --pkg=gee-0.8 --pkg=posix $^ -o aho-sudoku
