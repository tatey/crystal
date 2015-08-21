class TablePrint
  COL_SEP = '|'
  CELL_MARGIN = ' '

  struct Separator
  end

  class Column
    def initialize
      @max_length = 0
    end

    def width
      @max_length
    end

    def will_render(cell)
      @max_length = Math.max(@max_length, cell.text.length)
    end

    def render_cell(cell)
      case cell.align
      when :left
        "%-#{width}s" % cell.text
      when :right
        "%+#{width}s" % cell.text
      when :center
        left = " " * ((width - cell.text.length) / 2)
        right = " " * (width - cell.text.length - left.length)
        "#{left}#{cell.text}#{right}"
      end
    end
  end

  class Cell
    property text
    property align

    def initialize(@text, @align)
    end
  end

  alias RowTypes = Array(Cell) | Separator

  property! last_string_row

  def initialize(@io : IO)
    @data = [] of RowTypes
    @columns = [] of Column
  end

  def build
    with self yield self
    render
  end

  def separator
    @data << Separator.new
  end

  def row
    @last_string_row = [] of Cell
    @data << last_string_row
    with self yield
  end

  def cell(text, align = :left)
    cell = Cell.new(text, align)
    last_string_row << cell
    column_for_last_cell.will_render(cell)
  end

  protected def render
    @data.each_with_index do |data_row, i|
      @io << '\n' if i != 0
      if data_row.is_a?(Separator)
        @io << "-" * (@columns.sum(&.width) + 1 + 3 * @columns.length)
      elsif data_row.is_a?(Array(Cell))
        data_row.each_with_index do |cell, i|
          @io << COL_SEP if i == 0
          @io << CELL_MARGIN << @columns[i].render_cell(cell) << CELL_MARGIN << COL_SEP
        end
      end
    end
  end

  protected def column_for_last_cell
    col = @columns[last_string_row.length-1]?
    unless col
      col = Column.new
      @columns << col
    end
    col
  end
end
