$LOAD_PATH.unshift File.dirname(__FILE__) + "/../vendor/prawn/lib"
require "prawn"
require "prawn/measurement_extensions"

Prawn.debug = true

class Jambalaya < Prawn::Document

  def self.generate(outfile, &block)
    @doc = new(:top_margin => 0.75.in, 
               :bottom_margin => 1.in,
               :left_margin => 1.in,
               :right_margin => 1.in,
               :page_size => [7.0.in, 9.19.in])
    @doc.register_fonts
    @doc.setup_page_numbering

    @doc.instance_eval(&block)
    @doc.render_file(outfile)
  end

  def title(title_num, title_text)
    font "sans" do
      text "<b>#{title_num}</b>", :size          => 12, 
                                  :align         => :right,
                                  :inline_format => true
      stroke_horizontal_rule
      move_down 0.1.in

      text "<b>#{title_text}</b>", 
        :size          => 18, 
        :align         => :right,
        :inline_format => true
    end
      
    move_down 1.25.in
  end

  def section(section_text)
    move_down 0.1.in

    float do
      font("sans", :style => :bold, :size => 12) do
        text section_text
      end
    end
    
    move_down 0.25.in
  end

  def prose(prose_text)
    font("serif", :size => 9) do
      prose_text.split(/\n\n+/).each do |para|
        text para.gsub(/\s+/," "),
           :align         => :justify,
           :inline_format => true,
           :leading       => 2
        move_down 0.1.in
      end
    end
  end

  def code(code_text, size=7)
     font("mono", :size => size) do
       # no, you're not blind.  That's sub space with nbsp :)
       text code_text.gsub(' ', ' ')
     end

     move_down 0.1.in
  end

  def aside(title=nil)
    bounding_box([0, cursor], :width => bounds.width) do
      move_down 0.15.in

      span(bounds.width - font.height*1.5, :position => :center) do
        if title
          font("sans", :size => 11, :style => :bold) do
            text title, :align => :center
            move_down 10
          end
        end

        yield
      end

      move_down 0.05.in
      stroke_bounds
    end

    move_down 0.1.in
  end

  def register_fonts
    dejavu_path = File.dirname(__FILE__) + "/../fonts/dejavu"

    font_families["sans"] = {
      :normal       => "#{dejavu_path}/DejaVuSansCondensed.ttf",
      :italic       => "#{dejavu_path}/DejaVuSansCondensed-Oblique.ttf",
      :bold         => "#{dejavu_path}/DejaVuSansCondensed-Bold.ttf",
      :bold_italic  => "#{dejavu_path}/DejaVuSansCondensed-BoldOblique.ttf"
    }

    font_families["mono"] = {
      :normal       => "#{dejavu_path}/DejaVuSansMono.ttf",
      :italic       => "#{dejavu_path}/DejaVuSansMono-Oblique.ttf",
      :bold         => "#{dejavu_path}/DejaVuSansMono-Bold.ttf",
      :bold_italic  => "#{dejavu_path}/DejaVuSansMono-BoldOblique.ttf"
    }

    font_families["serif"] = {
      :normal       => "#{dejavu_path}/DejaVuSerif.ttf",
      :italic       => "#{dejavu_path}/DejaVuSerif-Italic.ttf",
      :bold         => "#{dejavu_path}/DejaVuSerif-Bold.ttf",
      :bold_italic  => "#{dejavu_path}/DejaVuSerif-BoldItalic.ttf"
    }
  end

  def setup_page_numbering
    repeat(:all, :dynamic => true) do
      stroke_line [bounds.left, bounds.bottom  - 0.2.in],
                  [bounds.right, bounds.bottom - 0.2.in]

      pn_width = width_of(page_number.to_s, :size => 6)

      font("serif") do
        draw_text page_number.to_s, :size => 6,
          :at => [bounds.right - pn_width, bounds.bottom - 0.4.in],
          :style => :bold
      end
    end
  end

end
