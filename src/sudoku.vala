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

namespace Aho {
    public const string[] LETTERS = {
        "1", "2", "3", "4", "5", "6", "7", "8",
        "9", "A", "B", "C", "D", "E", "F", "0"
    };

    public enum ModelSize {
        MODEL_9,
        MODEL_16;
        
        public int block_length() {
            if (this == MODEL_9) {
                return 3;
            } else {
                return 4;
            }
        }
        
        public int length() {
            if (this == MODEL_9) {
                return 9;
            } else {
                return 16;
            }
        }
    }
    
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

    public enum Theme {
        LIGHT,
        DARK
    }
    
    public class SudokuModel : Object {
        public ModelSize size { get; private set; }
        public signal void completed();
        private const uint8[,] DATA_DEFAULT_9 = {
            {1, 2, 3, 4, 5, 6, 7, 8, 9},
            {7, 8, 9, 1, 2, 3, 4, 5, 6},
            {4, 5, 6, 7, 8, 9, 1, 2, 3},
            {9, 1, 2, 3, 4, 5, 6, 7, 8},
            {6, 7, 8, 9, 1, 2, 3, 4, 5},
            {3, 4, 5, 6, 7, 8, 9, 1, 2},
            {8, 9, 1, 2, 3, 4, 5, 6, 7},
            {5, 6, 7, 8, 9, 1, 2, 3, 4},
            {2, 3, 4, 5, 6, 7, 8, 9, 1}
        };
        private const uint8[,] DATA_DEFAULT_16 = {
            {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16},
            {13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
            {9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8},
            {5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4},
            {16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
            {12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
            {8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7},
            {4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3},
            {15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14},
            {11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
            {7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6},
            {3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2},
            {14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
            {10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9},
            {6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5},
            {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1},
        };

        private Cell[,] cells;
        private int length;
        private int block_length;

        public SudokuModel(ModelSize size) {
            this.size = size;
            length = size.length();
            block_length = size.block_length();
            init_algorithm();
        }

        public int get_correct_value(int x, int y) {
            return cells[x, y].correct_value;
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
        
        public bool check_is_resetting_ok() {
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    uint8 num = cells[i, j].correct_value;
                    if (num == 0 || !is_not_in_row(num, i, j, false) || is_not_in_column(num, i, j, false) || is_not_in_area(num, i, j, false)) {
                        return false;
                    }
                }
            }
            return true;
        }

        private void init_algorithm() {
            uint8[,] data = DATA_DEFAULT_9;
            if (size == MODEL_16) {
                data = DATA_DEFAULT_16;
            }
            Random.set_seed((uint32) new DateTime.now_local().to_unix());
            uint8[] randomizer = new uint8[length];
            for (int i = 0; i < length; i++) {
                do {
                    uint8 r = (uint8) Random.int_range(1, length + 1);
                    if (!(r in randomizer)) {
                        randomizer[i] = r;
                        break;
                    }
                } while (true);
            }
            
            int time_loop = Random.int_range(100, 1000);
            for (int i = 0; i < time_loop; i++) {
                int random_value = Random.int_range(0, 6);
                switch (random_value) {
                  case 0:
                    {
                        int from = Random.int_range(0, length / block_length - 1);
                        int to = Random.int_range(1, length / block_length);
                        if (from < to) {
                            swap_values(data, from, to);
                        }
                    }
                    break;
                  case 1:
                    rotate_values(data);
                    break;
                  case 2:
                    {
                        int block_index = Random.int_range(0, block_length);
                        int start_index = block_index * block_length;
                        int end_index = block_index * block_length + block_length;
                        revert_horizontally(data, start_index, end_index);
                    }
                    break;
                  case 3:
                    {
                        int block_index = Random.int_range(0, block_length);
                        int start_index = block_index * block_length;
                        int end_index = block_index * block_length + block_length;
                        revert_vertically(data, start_index, end_index);
                    }
                    break;
                  case 4:
                    {
                        int block_index = Random.int_range(0, block_length);
                        int start_index = block_index * block_length;
                        int end_index = block_index * block_length + block_length;
                        slide_vertically(data, start_index, end_index);
                    }
                    break;
                  case 5:
                    {
                        int block_index = Random.int_range(0, block_length);
                        int start_index = block_index * block_length;
                        int end_index = block_index * block_length + block_length;
                        slide_horizontally(data, start_index, end_index);
                    }
                    break;
                }
            }
            
            int block_num = length / block_length;
            int[,] max_fixed_area = new int[block_num, block_num];
            for (int i = 0; i < length / block_length; i++) {
                for (int j = 0; j < length / block_length; j++) {
                    max_fixed_area[i, j] = Random.int_range(block_num - 1, block_num + 2);
                }
            }
            
            cells = new Cell[length, length];
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    cells[i, j].correct_value = randomizer[data[i, j] - 1];
                    int max_fixed_area_num = max_fixed_area[i / block_num, j / block_num];
                    int fixed_in_area = count_fixed_in_area(i, j);
                    int rest_in_area = count_rest_in_area(i, j);
                    if (fixed_in_area >= max_fixed_area_num) {
                        cells[i, j].status = EMPTY;
                    } else {
                        if (rest_in_area <= (max_fixed_area_num - fixed_in_area)) {
                            cells[i, j].status = FIXED;
                        } else {
                            if (Random.int_range(0, 3) == 0) {
                                cells[i, j].status = FIXED;
                            } else {
                                cells[i, j].status = EMPTY;
                            }
                        }
                    }
                    cells[i, j].temp_value = 0;
                }
            }
        }

        private void swap_values(uint8[,] src_data, int from, int to) {
            debug("swap_values: from = %d, to = %d", from, to);
            uint8[,] dest = new uint8[length, length];
            for (int i = 0; i < length; i++) {
                int k = i;
                if (i / block_length == from) {
                    k = to * block_length + i % block_length;
                } else if (i / block_length == to) {
                    k =     from * block_length + i % block_length;
                }
                for (int j = 0; j < length; j++) {
                    dest[k, j] = src_data[i, j];
                }
            }
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    src_data[i, j] = dest[i, j];
                }
            }
        }

        private void rotate_values(uint8[,] data) {
            uint8[,] temp = new uint8[length, length];
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    temp[j, length - 1 - i] = data[i, j];
                }
            }
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    data[i, j] = temp[i, j];
                }
            }
        }
        
        private void revert_horizontally(uint8[,] data, int start_index, int end_index) {
            uint8[,] temp = new uint8[length, length];
            for (int i = 0; i < length; i++) {
                for (int j = start_index, k = end_index - 1; j < end_index; j++, k--) {
                    temp[i, k] = data[i, j];
                }
            }
            for (int i = 0; i < length; i++) {
                for (int j = start_index; j < end_index; j++) {
                    data[i, j] = temp[i, j];
                }
            }
        }

        private void revert_vertically(uint8[,] data, int start_index, int end_index) {
            uint8[,] temp = new uint8[length, length];
            for (int i = start_index, k = end_index - 1; i < end_index; i++, k--) {
                for (int j = 0; j < length; j++) {
                    temp[k, j] = data[i, j];
                }
            }
            for (int i = start_index; i < end_index; i++) {
                for (int j = 0; j < length; j++) {
                    data[i, j] = temp[i, j];
                }
            }
        }
        
        private void slide_horizontally(uint8[,] data, int start_index, int end_index) {
            uint8[,] temp = new uint8[length, length];
            for (int i = 0; i < length; i++) {
                for (int j = start_index; j < end_index; j++) {
                    if (j + 1 == end_index) {
                        temp[i, start_index] = data[i, j];
                    } else {
                        temp[i, j + 1] = data[i, j];
                    }
                }
            }
            for (int i = 0; i < length; i++) {
                for (int j = start_index; j < end_index; j++) {
                    data[i, j] = temp[i, j];
                }
            }
        }

        private void slide_vertically(uint8[,] data, int start_index, int end_index) {
            uint8[,] temp = new uint8[length, length];
            for (int i = start_index; i < end_index; i++) {
                for (int j = 0; j < length; j++) {
                    if (i + 1 == end_index) {
                        temp[start_index, j] = data[i, j];
                    } else {
                        temp[i + 1, j] = data[i, j];
                    }
                }
            }
            for (int i = start_index; i < end_index; i++) {
                for (int j = 0; j < length; j++) {
                    data[i, j] = temp[i, j];
                }
            }
        }
        
        private int count_fixed_in_area(int row, int col) {
            int x1 = row / block_length * block_length;
            int x2 = x1 + block_length;
            int y1 = col / block_length * block_length;
            int y2 = y1 + block_length;
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
            int x1 = row / block_length * block_length;
            int x2 = x1 + block_length;
            int y1 = col / block_length * block_length;
            int y2 = y1 + block_length;
            return (x2 - row - 1) * block_length + (y2 - 1 - col) + 1;
        }

        private bool is_not_in_row(uint8 val, int row, int col, bool is_editing) {
            for (int j = 0; j < length; j++) {
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
            }
            return true;
        }

        private bool is_not_in_column(uint8 val, int row, int col, bool is_editing) {
            for (int i = 0; i < length; i++) {
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
            }
            return true;
        }

        private bool is_not_in_area(uint8 val, int row, int col, bool is_editing) {
            int x1 = row / block_length * block_length;
            int x2 = x1 + block_length;
            int y1 = col / block_length * block_length;
            int y2 = y1 + block_length;
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

        private bool is_completed() {
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
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
    }

    public class SudokuWidget : Gtk.DrawingArea {
        public signal void require_error_dialog(string message);
        public signal void completed();
        public bool is_debug_mode {
            get {
                return is_debug_mode_value;
            }
            set {
                is_debug_mode_value = value;
                queue_draw();
            }
        }
        public Theme theme {
            get {
                return theme_value;
            }
            set {
                theme_value = value;
                if (theme_value == LIGHT) {
                    border_color = {0.6, 0.6, 0.6, 1.0};
                    border_highlight_color = {0.0, 0.0, 0.0, 1.0};
                    cell_color = {1.0, 1.0, 1.0, 1.0};
                    number_color = {0.1, 0.1, 0.1, 1.0};
                } else {
                    border_color = {0.15, 0.15, 0.15, 1.0};
                    border_highlight_color = {0.6, 0.5, 0.2, 1.0};
                    cell_color = {0.1, 0.1, 0.1, 1.0};
                    number_color = {0.95, 0.95, 0.95, 1.0};
                }
                queue_draw();
            }
        }
        private const int MARGIN = 0;
        private int length = 9;
        private int cell_width = 50;
        private int cell_height = 50;
        private int border_width_thin = 2;
        private int border_width_fat = 4;
        private int block_length = 3;
        private const Gdk.RGBA HOVER_COLOR = {0.95, 0.9, 0.6, 1.0};
        private const Gdk.RGBA SELECTED_COLOR = {1.0, 0.5, 0.2, 1.0};
        private const Gdk.RGBA HIGHLIGHT_BG = {0.6, 0.5, 0.2, 1.0};
        private const Gdk.RGBA TEMP_COLOR = {0.4, 0.9, 0.6, 1.0};
        private const Gdk.RGBA DEBUG_BG = {0.5, 0.5, 0.5, 1.0};
        private const Gdk.RGBA DEBUG_FG = {0.8, 0.1, 0.1, 1.0};
        private Gdk.RGBA border_color;
        private Gdk.RGBA cell_color;
        private Gdk.RGBA number_color;
        private Gdk.RGBA border_highlight_color;
        private Gdk.Rectangle[,] rects;
        private Cairo.Rectangle rect;
        private int[] mouse_hover_position = {-1, -1};
        private int[] selected_position = {-1, -1};
        private SudokuModel? model;
        private bool is_debug_mode_value = false;
        private Theme theme_value = LIGHT;
        private double mouse_position_x;
        private double mouse_position_y;
        private int font_size;
        public SudokuWidget() {
            model = new SudokuModel(MODEL_9);
            init();
            add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK
                      | Gdk.EventMask.KEY_PRESS_MASK
                      | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        }

        public SudokuWidget.with_model(SudokuModel model) {
            bind_model(model);
            add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK
                      | Gdk.EventMask.KEY_PRESS_MASK
                      | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        }

        public void bind_model(SudokuModel model) {
            this.model = model;
            if (model.size == MODEL_9) {
                length = 9;
                block_length = 3;
                cell_width = 50;
                cell_height = 50;
                border_width_fat = 4;
                border_width_thin = 2;
                font_size = 32;
            } else {
                length = 16;
                block_length = 4;
                cell_width = 30;
                cell_height = 30;
                border_width_fat = 3;
                border_width_thin = 1;
                font_size = 22;
            }
            init();
            model.completed.connect(() => {
                completed();
            });
            selected_position[0] = -1;
            selected_position[1] = -1;
            queue_draw();
        }

        public bool check_is_resetting_ok() {
            return model.check_is_resetting_ok();
        }

        private void init() {
            rects = new Gdk.Rectangle[length + 1, length + 1];
            int[] x = new int[length + 1];
            int[] y = new int[length + 1];
            int n = 0;
            x[n] = MARGIN + border_width_fat;
            for (int i = 0; i < block_length; i++) {
                for (int j = 0; j < block_length - 1; j++) {
                    x[n + 1] = x[n] + cell_width + border_width_thin;
                    n++;
                }
                x[n + 1] = x[n] + cell_width + border_width_fat;
                n++;
            }
            n = 0;
            y[n] = MARGIN + border_width_fat;
            for (int i = 0; i < block_length; i++) {
                for (int j = 0; j < block_length - 1; j++) {
                    y[n + 1] = y[n] + cell_height + border_width_thin;
                    n++;
                }
                y[n + 1] = y[n] + cell_height + border_width_fat;
                n++;
            }
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    rects[i, j].x = x[j];
                    rects[i, j].width = cell_width;
                    rects[i, j].y = y[i];
                    rects[i, j].height = cell_height;
                }
            }
            rect = Cairo.Rectangle() {
                x = (double) MARGIN,
                y = (double) MARGIN,
                width = (double) x[length],
                height = (double) y[length]
            };
            width_request = x[length];
            height_request = y[length];
        }

        public void put_value(int number) {
            bool success = false;
            if (model.size == MODEL_9) {
                if (0 < number && number < 10) {
                    success = model.set_temp_value(selected_position[0], selected_position[1], number);
                } else {
                    success = false;
                }
            } else {
                if (0 < number && number < 17) {
                    success = model.set_temp_value(selected_position[0], selected_position[1], number);
                } else {
                    success = false;
                }
            }
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

            if (mouse_hover_position[0] >= 0 && mouse_hover_position[1] >= 0) {
                Cairo.Pattern pattern_bg = new Cairo.Pattern.radial(mouse_position_x, mouse_position_y, 0,
                        mouse_position_x, mouse_position_y, cell_width * 5.0);
                pattern_bg.add_color_stop_rgb(cell_width / 2, border_color.red, border_color.green, border_color.blue);
                pattern_bg.add_color_stop_rgb(0, border_highlight_color.red, border_highlight_color.green, border_highlight_color.blue);
                cairo.set_source(pattern_bg);
            } else {
                cairo.set_source_rgb(border_color.red, border_color.green, border_color.blue);
            }
            cairo.set_line_width(0.0);

            cairo.rectangle(rect.x, rect.y, rect.width - rect.x, rect.height - rect.y);
            cairo.fill();

            cairo.select_font_face("Serif", NORMAL, NORMAL);
            cairo.set_font_size(font_size);
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    if (model.get_status(i, j) == FIXED) {
                        cairo.set_source_rgb(cell_color.red, cell_color.green, cell_color.blue);
                    } else if (is_debug_mode) {
                        cairo.set_source_rgb(DEBUG_BG.red, DEBUG_BG.green, DEBUG_BG.blue);
                    } else {
                        if (is_selected(i, j)) {
                            Cairo.Pattern pattern = new Cairo.Pattern.radial(rects[i, j].x + cell_width / 2, rects[i, j].y + cell_height / 2, 0,
                                    rects[i, j].x + cell_width / 2, rects[i, j].y + cell_height / 2, cell_width * 2.0);
                            pattern.add_color_stop_rgb(cell_width / 2, cell_color.red, cell_color.green, cell_color.blue);
                            pattern.add_color_stop_rgb(0, SELECTED_COLOR.red, SELECTED_COLOR.green, SELECTED_COLOR.blue);
                            cairo.set_source(pattern);
                        } else if (is_in_highlight(i, j)) {
                            Cairo.Pattern pattern = new Cairo.Pattern.radial(mouse_position_x, mouse_position_y, 0,
                                    mouse_position_x, mouse_position_y, cell_width * 3.0);
                            pattern.add_color_stop_rgb(cell_width / 2, cell_color.red, cell_color.green, cell_color.blue);
                            pattern.add_color_stop_rgb(0, HOVER_COLOR.red, HOVER_COLOR.green, HOVER_COLOR.blue);
                            cairo.set_source(pattern);
                        } else if (model.get_temp_value(i, j) > 0) {
                            Cairo.Pattern pattern = new Cairo.Pattern.linear(rects[i, j].x, rects[i, j].y, rects[i, j].x + rects[i, j].width,
                                    rects[i, j].y + rects[i, j].height);
                            pattern.add_color_stop_rgb(0.1, TEMP_COLOR.red, TEMP_COLOR.green, TEMP_COLOR.blue);
                            pattern.add_color_stop_rgb(0.5, cell_color.red, cell_color.green, cell_color.blue);
                            pattern.add_color_stop_rgb(0.9, TEMP_COLOR.red, TEMP_COLOR.green, TEMP_COLOR.blue);
                            cairo.set_source(pattern);
                        } else {
                            cairo.set_source_rgb(cell_color.red, cell_color.green, cell_color.blue);
                        }
                    }
                    cairo.rectangle(
                        (double) rects[i, j].x,
                        (double) rects[i, j].y,
                        cell_width,
                        cell_height
                    );
                    cairo.fill();

                    if (is_debug_mode) {
                        cairo.set_source_rgb(DEBUG_FG.red, DEBUG_FG.green, DEBUG_FG.blue);
                    } else {
                        cairo.set_source_rgb(number_color.red, number_color.green, number_color.blue);
                    }
                    int num = 0;
                    if (model.get_status(i, j) == FIXED) {
                        num = model.get_correct_value(i, j);
                    }
                    if (model.get_status(i, j) != FIXED) {
                        if (is_debug_mode) {
                            num = model.get_correct_value(i, j);
                        } else {
                            num = model.get_temp_value(i, j);
                        }
                    }
                    if (num > 0) {
                        string num_s = LETTERS[num - 1];
                        cairo.text_extents(num_s, out extents);
                        double x = (cell_width / 2) - (extents.width / 2 + extents.x_bearing);
                        double y = (cell_height / 2) - (extents.height / 2 + extents.y_bearing);
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
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    if (rects[i, j].x <= x && x <= rects[i, j].x + cell_width
                            && rects[i, j].y <= y && y <= rects[i, j].y + cell_height) {
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
            for (int i = 0; i < length; i++) {
                for (int j = 0; j < length; j++) {
                    if (rects[i, j].x <= x && x <= rects[i, j].x + cell_width
                            && rects[i, j].y <= y && y <= rects[i, j].y + cell_height) {
                        if (mouse_hover_position[0] != i || mouse_hover_position[1] != j) {
                            mouse_hover_position[0] = i;
                            mouse_hover_position[1] = j;
                            mouse_position_x = event.x;
                            mouse_position_y = event.y;
                            queue_draw();
                            return true;
                        } else if (mouse_hover_position[0] == i && mouse_hover_position[1] == j) {
                            mouse_position_x = event.x;
                            mouse_position_y = event.y;
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
}

int main(string[] argv) {
    bool is_debug = false;
    if (argv.length > 1) {
        for (int i = 0; i < argv.length; i++) {
            switch (argv[i]) {
              case "--version": case "-v":
                print("Aho-Sudoku 0.0.1\n");
                return 0;
              case "--debug": case "-d":
                is_debug = true;
                break;
              case "--help": case "-h": case "-?":
                print("""Aho-Sudoku version 0.0.1

Usage:
    com.github.aharotias2.aho-sudoku [OPTION...]

Options:
    --version   -v      print this version
    --debug     -d      launch in debug mode
    --help      -h      print this help

GPLv3 Copyright (C) 2021 Takayuki Tanaka <https://github.com/aharotias2>
""");
                return 0;
            }
        }
    }
    var app = new Gtk.Application("com.github.aharotias2.sudoku", FLAGS_NONE);
    app.activate.connect(() => {
        Aho.SudokuWidget? widget = null;
        Gtk.Label? message_label = null;
        Gtk.ButtonBox? button_box_9 = null;
        Gtk.Box? button_box_16 = null;
        Gtk.Button? reset_button = null;
        var window = new Gtk.ApplicationWindow(app);
        {
            var header_bar = new Gtk.HeaderBar();
            {
                var hard_switch = new Gtk.Switch();
                {
                    hard_switch.tooltip_text = "Enable the hard mode";
                    hard_switch.state_set.connect((state) => {
                        reset_button.clicked();
                        return false;
                    });
                }
                
                reset_button = new Gtk.Button.with_label("Reset");
                {
                    reset_button.clicked.connect(() => {
                        Aho.SudokuModel? new_model = null;
                        if (hard_switch.active) {
                            new_model = new Aho.SudokuModel(MODEL_16);
                            button_box_16.visible = true;
                            button_box_9.visible = false;
                        } else {
                            new_model = new Aho.SudokuModel(MODEL_9);
                            button_box_9.visible = true;
                            button_box_16.visible = false;
                        }
                        widget.bind_model(new_model);
                        if (widget.check_is_resetting_ok()) {
                            message_label.label = @"<span color=\"red\"><b>リセットがうまくいっていません。</b></span>";
                            Timeout.add(3000, () => {
                                message_label.label = "";
                                return false;
                            });
                        }
                    });
                }

                var switch_button = new Gtk.Switch();
                {
                    switch_button.tooltip_text = "Enable the dark mode";
                    switch_button.state_set.connect((state) => {
                        widget.theme = switch_button.active ? Aho.Theme.DARK : Aho.Theme.LIGHT;
                        var gtk_settings = Gtk.Settings.get_default();
                        if (widget.theme == DARK) {
                            gtk_settings.gtk_application_prefer_dark_theme = true;
                        } else {
                            gtk_settings.gtk_application_prefer_dark_theme = false;
                        }
                        return true;
                    });
                }
                
                header_bar.pack_start(hard_switch);
                header_bar.pack_start(reset_button);
                header_bar.pack_end(switch_button);
                header_bar.show_close_button = true;
            }
            
            var box_1 = new Gtk.Box(VERTICAL, 0);
            {
                var box_2 = new Gtk.Box(HORIZONTAL, 0);
                {
                    message_label = new Gtk.Label("") {
                        use_markup = true
                    };
    
                    Gtk.ToggleButton? debug_button = null;
                    if (is_debug) {
                        debug_button = new Gtk.ToggleButton.with_label("Debug");
                        {
                            debug_button.toggled.connect(() => {
                                widget.is_debug_mode = debug_button.active;
                            });
                        }
                    }
                    
                    box_2.pack_start(message_label, true, true);
                    if (is_debug) {
                        box_2.pack_start(debug_button, false, false);
                    }
                    box_2.margin = 10;
                }

                Aho.SudokuModel? model = new Aho.SudokuModel(MODEL_9);
                widget = new Aho.SudokuWidget.with_model(model);
                {
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
                    var gtk_settings = Gtk.Settings.get_default();
                    if (gtk_settings.gtk_application_prefer_dark_theme) {
                        widget.theme = Aho.Theme.DARK;
                    } else {
                        widget.theme = Aho.Theme.LIGHT;
                    }
                }

                button_box_9 = new Gtk.ButtonBox(HORIZONTAL);
                {
                    for (int i = 0; i < 9; i++) {
                        var number_button = new Gtk.Button.with_label((i + 1).to_string());
                        {
                            int number = i + 1;
                            number_button.clicked.connect(() => {
                                widget.put_value(number);
                            });
                        }
                        button_box_9.pack_start(number_button);
                    }
                    var del_button = new Gtk.Button.from_icon_name("edit-delete-symbolic");
                    {
                        del_button.clicked.connect(() => {
                            widget.delete_value();
                        });
                    }

                    button_box_9.pack_start(del_button);
                    button_box_9.layout_style = EXPAND;
                    button_box_9.margin = 10;
                }

                button_box_16 = new Gtk.Box(VERTICAL, 5);
                {
                    for (int i = 0; i < 2; i++) {
                        var button_box_16_inner = new Gtk.ButtonBox(HORIZONTAL);
                        {
                            for (int j = 0; j < 8; j++) {
                                var number_button = new Gtk.Button.with_label(Aho.LETTERS[i * 8 + j]);
                                {
                                    int number = i * 8 + j + 1;
                                    number_button.clicked.connect(() => {
                                        widget.put_value(number);
                                    });
                                }
                                button_box_16_inner.pack_start(number_button);
                            }

                            var del_button = new Gtk.Button.from_icon_name("edit-delete-symbolic");
                            {
                                del_button.clicked.connect(() => {
                                    widget.delete_value();
                                });
                            }

                            button_box_16_inner.pack_start(del_button);
                            button_box_16_inner.layout_style = EXPAND;
                        }
                        
                        button_box_16.pack_start(button_box_16_inner, false, false);
                    }
                    
                    button_box_16.margin = 10;
                }

                box_1.pack_start(box_2, false, false);
                box_1.pack_start(widget, true, true);
                box_1.pack_start(button_box_9, false, false);
                box_1.pack_start(button_box_16, false, false);
            }
            
            window.set_titlebar(header_bar);
            window.add(box_1);
            window.key_press_event.connect((event) => {
                uint8 num = 0;
                if (event.state == CONTROL_MASK) {
                    switch (event.keyval) {
                      case Gdk.Key.q:
                      case Gdk.Key.w:
                        app.quit();
                        break;
                    }
                } else {
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
                      case Gdk.Key.a:
                        num = 10;
                        break;
                      case Gdk.Key.b:
                        num = 11;
                        break;
                      case Gdk.Key.c:
                        num = 12;
                        break;
                      case Gdk.Key.d:
                        num = 13;
                        break;
                      case Gdk.Key.e:
                        num = 14;
                        break;
                      case Gdk.Key.f:
                        num = 15;
                        break;
                      case Gdk.Key.@0:
                        num = 16;
                        break;
                      case Gdk.Key.BackSpace:
                        num = 0;
                        break;
                      default:
                        return false;
                    }
                }
                widget.put_value(num);
                return true;
            });
            
            window.add_events(Gdk.EventMask.KEY_PRESS_MASK);
            window.set_default_size(550, 650);
            window.title = "Let's Sudoku";
        }
        
        window.show_all();
        button_box_16.visible = false;
    });
    
    return app.run(null);
}
