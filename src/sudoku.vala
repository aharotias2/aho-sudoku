/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * Copyright 2020 Takayuki Tanaka
 */

public enum CellStatus {
    EMPTY,
    FIXED,
    EDITED
}

public struct Cell {
    public CellStatus status;
    public uint8 correct_value;
    public uint8 temp_value;
}

public class SudokuModel : Object {
    public signal void completed();
    
    private Cell[,] cells;
    private uint64 try_count;
    private int progress;
    private const int MAX_FIXED_AREA = 3;
    
    public SudokuModel() {
        Random.set_seed((uint32) new DateTime.now_local().to_unix());
        int n = 0;
        print("\033[?25l");
        Posix.sigaction_t term_action = Posix.sigaction_t();
        term_action.sa_handler = (@signal) => {
            print("\n");
            print("\033[?25h");
            Process.exit(1);
        };
        Posix.sigaction(Posix.Signal.TERM, term_action, null);
        Posix.sigaction(Posix.Signal.INT, term_action, null);
        Cell[,]? max_cells = null;
        int max_progress = 0;
        do {
            try_count = 0;
            progress = 0;
            cells = new Cell[9, 9];
            for (int i = 0; i < 9; i++) {
                for (int j = 0; j < 9; j++) {
                    cells[i, j].correct_value = 0;
                    cells[i, j].temp_value = 0;
                    for (int k = 0; k < 100; k++) {
                        uint8 val = (uint8) Random.int_range(1, 10);
                        if (is_not_in_row(val, i, j, false) && is_not_in_column(val, i, j, false)
                                && is_not_in_area(val, i, j, false)) {
                            int fixed_in_area = count_fixed_in_area(i, j);
                            int rest_in_area = count_rest_in_area(i, j);
                            if (fixed_in_area >= MAX_FIXED_AREA) {
                                cells[i, j].status = EMPTY;
                            } else {
                                if (rest_in_area <= (MAX_FIXED_AREA - fixed_in_area)) {
                                    cells[i, j].status = FIXED;
                                } else {
                                    if (Random.boolean()) {
                                        cells[i, j].status = FIXED;
                                    } else {
                                        cells[i, j].status = EMPTY;
                                    }
                                }
                            }
                            cells[i, j].correct_value = val;
                            cells[i, j].temp_value = 0;
                            progress++;
                            break;
                        }
                    }
                }
            }
            n++;
            if (max_progress < progress) {
                max_progress = progress;
                max_cells = cells;
            }
        } while (progress >= 81 || n < 1);
        print("\033[?25h");
        print("\n");
        cells = max_cells;
    }
    
    public int get_correct_value(int x, int y) {
        if (cells[x, y].status == FIXED) {
            return cells[x, y].correct_value;
        } else {
            return 0;
        }
    }
    
    public int get_temp_value(int x, int y) {
        if (cells[x, y].status == EDITED) {
            return cells[x, y].temp_value;
        } else {
            return 0;
        }
    }
    
    public bool set_temp_value(int x, int y, int val) {
        if (cells[x, y].status != FIXED) {
            if (val == 0) {
                cells[x, y].temp_value = 0;
                cells[x, y].status = EMPTY;
                return true;
            } else if (is_not_in_row((uint8) val, x, y, true) && is_not_in_column((uint8) val, x, y, true)
                    && is_not_in_area((uint8) val, x, y, true)) {
                cells[x, y].temp_value = (uint8) val;
                cells[x, y].status = EDITED;
                if (is_completed()) {
                    completed();
                }
                return true;
            } else {
                return false;
            }
        } else {
            return true;
        }
    }
    
    public CellStatus get_status(int x, int y) {
        return cells[x, y].status;
    }
    
    private bool is_not_in_row(uint8 val, int row, int col, bool is_editing) {
        for (int j = 0; j < 9; j++) {
            try_count++;
            if (is_editing) {
                if (cells[row, j].status == FIXED) {
                    if (val == cells[row, j].correct_value) {
                        return false;
                    }
                } else {
                    if (val == cells[row, j].temp_value) {
                        return false;
                    }
                }
            } else {
                if (val == cells[row, j].correct_value) {
                    return false;
                }
            }
            print_progress();
        }
        return true;
    }
    
    private bool is_not_in_column(uint8 val, int row, int col, bool is_editing) {
        for (int i = 0; i < 9; i++) {
            try_count++;
            if (is_editing) {
                if (cells[i, col].status == FIXED) {
                    if (val == cells[i, col].correct_value) {
                        return false;
                    }
                } else {
                    if (val == cells[i, col].temp_value) {
                        return false;
                    }
                }
            } else {
                if (val == cells[i, col].correct_value) {
                    return false;
                }
            }
            print_progress();
        }
        return true;
    }
    
    private bool is_not_in_area(uint8 val, int row, int col, bool is_editing) {
        int x1 = row / 3 * 3;
        int x2 = x1 + 3;
        int y1 = col / 3 * 3;
        int y2 = y1 + 3;
        for (int i = x1; i < x2; i++) {
            for (int j = y1; j < y2; j++) {
                if (is_editing) {
                    if (cells[i, j].status == FIXED) {
                        if (cells[i, j].correct_value == val) {
                            return false;
                        }
                    } else {
                        if (cells[i, j].temp_value == val) {
                            return false;
                        }
                    }
                } else {
                    if (cells[i, j].correct_value == val) {
                        return false;
                    }
                }
            }
        }
        return true;
    }
    
    private int count_fixed_in_area(int row, int col) {
        int x1 = row / 3 * 3;
        int x2 = x1 + 3;
        int y1 = col / 3 * 3;
        int y2 = y1 + 3;
        int count = 0;
        for (int i = x1; i < x2; i++) {
            for (int j = y1; j < y2; j++) {
                if (cells[i, j].status == FIXED) {
                    count++;
                }
            }
        }
        return count;
    }
    
    private int count_rest_in_area(int row, int col) {
        int x1 = row / 3 * 3;
        int x2 = x1 + 3;
        int y1 = col / 3 * 3;
        int y2 = y1 + 3;
        return (x2 - row - 1) * 3 + (y2 - 1 - col) + 1;
    }
    
    private bool is_completed() {
        for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
                uint8 num = 0;
                if (cells[i, j].status == FIXED) {
                    num = cells[i, j].correct_value;
                } else {
                    num = cells[i, j].temp_value;
                }
                if (num == 0 || !is_not_in_row(num, i, j, true) || is_not_in_column(num, i, j, true) || is_not_in_area(num, i, j, true)) {
                    return false;
                }
            }
        }
        return true;
    }
    
    private void print_progress() {
        if (try_count > 0) {
            print("\033[18D");
        }
        print("%10llu %2d %3d%%", try_count, progress, (int) ((((double) progress) / 81.0) * 100));
    }
}

public class SudokuWidget : Gtk.DrawingArea {
    public signal void require_error_dialog(string message);
    public signal void completed();
    private const int MARGIN = 0;
    private const int CELL_WIDTH = 50;
    private const int CELL_HEIGHT = 50;
    private const int CELL_BORDER_WIDTH_THIN = 2;
    private const int CELL_BORDER_WIDTH_FAT = 4;
    private const Gdk.RGBA HOVER_COLOR = {1.0, 0.9, 0.6, 1.0};
    private const Gdk.RGBA SELECTED_COLOR = {1.0, 0.5, 0.2, 1.0};
    private const Gdk.RGBA TEMP_COLOR = {0.5, 1.0, 0.7, 1.0};
    private const Gdk.RGBA DEFAULT_BG = {1.0, 1.0, 1.0, 1.0};
    private const Gdk.RGBA DEFAULT_FG = {0.1, 0.1, 0.1, 1.0};
    private Gdk.Rectangle[,] rects;
    private Cairo.Rectangle rect;
    private int[] mouse_hover_position = {-1, -1};
    private int[] selected_position = {-1, -1};
    private SudokuModel? model;
    
    public SudokuWidget() {
        init();
    }
    
    public SudokuWidget.with_model(SudokuModel model) {
        this.model = model;
        model.completed.connect(() => {
            completed();
        });
        init();
    }
    
    public void bind_model(SudokuModel model) {
        this.model = model;
        model.completed.connect(() => {
            completed();
        });
        selected_position[0] = -1;
        selected_position[1] = -1;
        queue_draw();
    }
    
    private void init() {
        rects = new Gdk.Rectangle[10, 10];
        int[] x = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        int[] y = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        x[0] = MARGIN + CELL_BORDER_WIDTH_FAT;
        x[1] = x[0] + CELL_WIDTH + CELL_BORDER_WIDTH_THIN;
        x[2] = x[1] + CELL_WIDTH + CELL_BORDER_WIDTH_THIN;
        x[3] = x[2] + CELL_WIDTH + CELL_BORDER_WIDTH_FAT;
        x[4] = x[3] + CELL_WIDTH + CELL_BORDER_WIDTH_THIN;
        x[5] = x[4] + CELL_WIDTH + CELL_BORDER_WIDTH_THIN;
        x[6] = x[5] + CELL_WIDTH + CELL_BORDER_WIDTH_FAT;
        x[7] = x[6] + CELL_WIDTH + CELL_BORDER_WIDTH_THIN;
        x[8] = x[7] + CELL_WIDTH + CELL_BORDER_WIDTH_THIN;
        x[9] = x[8] + CELL_WIDTH + CELL_BORDER_WIDTH_FAT;
        y[0] = MARGIN + CELL_BORDER_WIDTH_FAT;
        y[1] = y[0] + CELL_HEIGHT + CELL_BORDER_WIDTH_THIN;
        y[2] = y[1] + CELL_HEIGHT + CELL_BORDER_WIDTH_THIN;
        y[3] = y[2] + CELL_HEIGHT + CELL_BORDER_WIDTH_FAT;
        y[4] = y[3] + CELL_HEIGHT + CELL_BORDER_WIDTH_THIN;
        y[5] = y[4] + CELL_HEIGHT + CELL_BORDER_WIDTH_THIN;
        y[6] = y[5] + CELL_HEIGHT + CELL_BORDER_WIDTH_FAT;
        y[7] = y[6] + CELL_HEIGHT + CELL_BORDER_WIDTH_THIN;
        y[8] = y[7] + CELL_HEIGHT + CELL_BORDER_WIDTH_THIN;
        y[9] = y[8] + CELL_HEIGHT + CELL_BORDER_WIDTH_FAT;
        for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
                rects[i, j].x = x[j];
                rects[i, j].width = CELL_WIDTH;
                rects[i, j].y = y[i];
                rects[i, j].height = CELL_HEIGHT;
            }
        }
        rect = Cairo.Rectangle() {
            x = (double) MARGIN,
            y = (double) MARGIN,
            width = (double) x[9],
            height = (double) y[9]
        };
        add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK
                  | Gdk.EventMask.KEY_PRESS_MASK
                  | Gdk.EventMask.LEAVE_NOTIFY_MASK);
    }

    public void put(int number) {
        bool success = model.set_temp_value(selected_position[0], selected_position[1], number);
        if (success) {
            selected_position[0] = -1;
            selected_position[1] = -1;
            queue_draw();
        } else {
            require_error_dialog("そこにその数字は入れられません!");
        }
    }

    public void delete_value() {
        bool success = model.set_temp_value(selected_position[0], selected_position[1], 0);
        if (success) {
            selected_position[0] = -1;
            selected_position[1] = -1;
            queue_draw();
        }
    }
    
    public override bool draw(Cairo.Context cairo) {
        Cairo.TextExtents extents;
        cairo.set_source_rgb(DEFAULT_FG.red, DEFAULT_FG.green, DEFAULT_FG.blue);
        cairo.set_line_width(0.0);
        cairo.rectangle(rect.x, rect.y, rect.width - rect.x, rect.height - rect.y);
        cairo.fill();
        
        cairo.select_font_face("Sans", NORMAL, NORMAL);
        cairo.set_font_size(24);
        for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
                if (model.get_status(i, j) == FIXED) {
                    cairo.set_source_rgb(DEFAULT_BG.red, DEFAULT_BG.green, DEFAULT_BG.blue);
                } else if (is_selected(i, j)) {
                    Cairo.Pattern pattern = new Cairo.Pattern.radial(rects[i, j].x + CELL_WIDTH / 2, rects[i, j].y + CELL_HEIGHT / 2, 0,
                            rects[i, j].x + CELL_WIDTH / 2, rects[i, j].y + CELL_HEIGHT / 2, CELL_WIDTH);
                    pattern.add_color_stop_rgb(CELL_WIDTH / 2, DEFAULT_BG.red, DEFAULT_BG.green, DEFAULT_BG.blue);
                    pattern.add_color_stop_rgb(0, SELECTED_COLOR.red, SELECTED_COLOR.green, SELECTED_COLOR.blue);
                    cairo.set_source(pattern);
                } else if (is_in_highlight(i, j)) {
                    Cairo.Pattern pattern = new Cairo.Pattern.radial(rects[i, j].x + CELL_WIDTH / 2, rects[i, j].y + CELL_HEIGHT / 2, 0,
                            rects[i, j].x + CELL_WIDTH / 2, rects[i, j].y + CELL_HEIGHT / 2, CELL_WIDTH * 1.5);
                    pattern.add_color_stop_rgb(CELL_WIDTH / 2, DEFAULT_BG.red, DEFAULT_BG.green, DEFAULT_BG.blue);
                    pattern.add_color_stop_rgb(0, HOVER_COLOR.red, HOVER_COLOR.green, HOVER_COLOR.blue);
                    cairo.set_source(pattern);
                } else if (model.get_temp_value(i, j) > 0) {
                    Cairo.Pattern pattern = new Cairo.Pattern.linear(rects[i, j].x, rects[i, j].y, rects[i, j].x + rects[i, j].width,
                            rects[i, j].y + rects[i, j].height);
                    pattern.add_color_stop_rgb(0.1, TEMP_COLOR.red, TEMP_COLOR.green, TEMP_COLOR.blue);
                    pattern.add_color_stop_rgb(0.5, DEFAULT_BG.red, DEFAULT_BG.green, DEFAULT_BG.blue);
                    pattern.add_color_stop_rgb(0.9, TEMP_COLOR.red, TEMP_COLOR.green, TEMP_COLOR.blue);
                    cairo.set_source(pattern);
                } else {
                    cairo.set_source_rgb(DEFAULT_BG.red, DEFAULT_BG.green, DEFAULT_BG.blue);
                }
                cairo.rectangle(
                    (double) rects[i, j].x,
                    (double) rects[i, j].y,
                    CELL_WIDTH,
                    CELL_HEIGHT
                );
                cairo.fill();
                
                cairo.set_source_rgb(DEFAULT_FG.red, DEFAULT_FG.green, DEFAULT_FG.blue);
                int num = 0;
                if (model.get_status(i, j) == FIXED) {
                    num = model.get_correct_value(i, j);
                }
                if (model.get_status(i, j) != FIXED) {
                    num = model.get_temp_value(i, j);
                }
                if (num > 0) {
                    string num_s = num.to_string();
                    cairo.text_extents(num_s, out extents);
                    double x = (CELL_WIDTH / 2) - (extents.width / 2 + extents.x_bearing);
                    double y = (CELL_HEIGHT / 2) - (extents.height / 2 + extents.y_bearing);
                    cairo.move_to(rects[i, j].x + x, rects[i, j].y + y);
                    cairo.show_text(num_s);
                }
            }
        }
        return true;
    }
    
    public override bool button_press_event(Gdk.EventButton event) {
        int x = (int) event.x;
        int y = (int) event.y;
        for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
                if (rects[i, j].x <= x && x <= rects[i, j].x + CELL_WIDTH
                        && rects[i, j].y <= y && y <= rects[i, j].y + CELL_HEIGHT) {
                    if (selected_position[0] == i && selected_position[1] == j) {
                        if (model.get_status(i, j) != FIXED) {
                            selected_position[0] = -1;
                            selected_position[1] = -1;
                            queue_draw();
                            return true;
                        }
                    }
                    if (selected_position[0] != i || selected_position[1] != j) {
                        selected_position[0] = i;
                        selected_position[1] = j;
                        queue_draw();
                        return true;
                    }
                    return false;
                }
            }
        }
        selected_position[0] = -1;
        selected_position[1] = -1;
        queue_draw();
        return false;
    }
        
    public override bool button_release_event(Gdk.EventButton event) {
        return false;
    }
    
    public override bool leave_notify_event(Gdk.EventCrossing event) {
        mouse_hover_position[0] = -1;
        mouse_hover_position[1] = -1;
        queue_draw();
        return false;
    }
    
    public override bool motion_notify_event(Gdk.EventMotion event) {
        int x = (int) event.x;
        int y = (int) event.y;
        for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
                if (rects[i, j].x <= x && x <= rects[i, j].x + CELL_WIDTH
                        && rects[i, j].y <= y && y <= rects[i, j].y + CELL_HEIGHT) {
                    if (mouse_hover_position[0] != i || mouse_hover_position[1] != j) {
                        mouse_hover_position[0] = i;
                        mouse_hover_position[1] = j;
                        queue_draw();
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    private bool is_in_highlight(int x, int y) {
        return x == mouse_hover_position[0] && y == mouse_hover_position[1];
    }
    
    private bool is_selected(int x, int y) {
        return x == selected_position[0] && y == selected_position[1];
    }
}

int main(string[] argv) {
    var app = new Gtk.Application("com.github.aharotias2.sudoku", FLAGS_NONE);
    app.activate.connect(() => {
        SudokuWidget? widget = null;
        Gtk.Label? message_label = null;
        var window = new Gtk.ApplicationWindow(app);
        var box_1 = new Gtk.Box(VERTICAL, 0);
        {
            SudokuModel? model = null;
            
            var box_2 = new Gtk.Box(HORIZONTAL, 0);
            {
                var reset_button = new Gtk.Button.with_label("Reset");
                reset_button.clicked.connect(() => {
                    model = new SudokuModel();
                    widget.bind_model(model);
                });
                message_label = new Gtk.Label("") {
                    use_markup = true
                };
                box_2.pack_start(reset_button, false, false);
                box_2.pack_start(message_label, true, true);
                box_2.margin = 10;
            }
            
            model = new SudokuModel();
            widget = new SudokuWidget.with_model(model);
            widget.require_error_dialog.connect((message) => {
                message_label.label = @"<span color=\"red\"><b>$(message)</b></span>";
                Timeout.add(3000, () => {
                    message_label.label = "";
                    return false;
                });
            });
            widget.completed.connect(() => {
                var dialog = new Gtk.MessageDialog(window, MODAL, INFO, OK, "おめでとうございます。あなたはゲームに勝ちました!");
                dialog.run();
                dialog.close();
            });
            widget.margin = 10;
            var box_3 = new Gtk.ButtonBox(HORIZONTAL);
            {
                for (int i = 0; i < 9; i++) {
                    var number_button = new Gtk.Button.with_label((i + 1).to_string());
                    int number = i + 1;
                    number_button.clicked.connect(() => {
                        widget.put(number);
                    });
                    box_3.pack_start(number_button);
                }
                var del_button = new Gtk.Button.from_icon_name("edit-delete-symbolic");
                del_button.clicked.connect(() => {
                    widget.delete_value();
                });
                box_3.pack_start(del_button);
                box_3.layout_style = EXPAND;
                box_3.margin = 10;
            }
            
            box_1.pack_start(box_2, false, false);
            box_1.pack_start(widget, true, true);
            box_1.pack_start(box_3, false, false);
        }
        window.add(box_1);
        window.key_press_event.connect((event) => {
            uint8 num = 0;
            switch (event.keyval) {
              case Gdk.Key.@1:
                num = 1;
                break;
              case Gdk.Key.@2:
                num = 2;
                break;
              case Gdk.Key.@3:
                num = 3;
                break;
              case Gdk.Key.@4:
                num = 4;
                break;
              case Gdk.Key.@5:
                num = 5;
                break;
              case Gdk.Key.@6:
                num = 6;
                break;
              case Gdk.Key.@7:
                num = 7;
                break;
              case Gdk.Key.@8:
                num = 8;
                break;
              case Gdk.Key.@9:
                num = 9;
                break;
              case Gdk.Key.@0:
              case Gdk.Key.BackSpace:
                num = 0;
                break;
              default:
                return false;
            }
            widget.put(num);
            return true;
        });
        window.add_events(Gdk.EventMask.KEY_PRESS_MASK);
        window.set_default_size(550, 650);
        window.title = "Let's Sudoku";
        window.show_all();
    });
    return app.run(argv);
}
