require "spec"
require "table_print"

def assert_table(expected)
  actual = String::Builder.build do |builder|
    TablePrint.new(builder).build do |tp|
      with tp yield
    end
  end

  actual.should eq(expected[1..-1])
end

describe TablePrint do
  it "single cell" do
    assert_table %(
| A |) do
      row do
        cell "A"
      end
    end
  end

  it "single row with separator" do
    assert_table %(
| A | B |) do
      row do
        cell "A"
        cell "B"
      end
    end
  end

  it "multiple rows with separator" do
    assert_table %(
| A | B |
| C | D |) do
      row do
        cell "A"
        cell "B"
      end
      row do
        cell "C"
        cell "D"
      end
    end
  end

  it "rows with horizontal separators" do
    assert_table %(
| A | B |
---------
| C | D |) do
      row do
        cell "A"
        cell "B"
      end
      separator
      row do
        cell "C"
        cell "D"
      end
    end
  end

  it "aligns columns borders" do
    assert_table %(
| A   | Foo |
-------------
| Bar | D   |) do
      row do
        cell "A"
        cell "Foo"
      end
      separator
      row do
        cell "Bar"
        cell "D"
      end
    end
  end

  it "aligns cell content" do
    assert_table %(
|  A  | Fooo |
--------------
| Bar |    D |) do
      row do
        cell "A", align: :center
        cell "Fooo"
      end
      separator
      row do
        cell "Bar"
        cell "D", align: :right
      end
    end
  end
end
