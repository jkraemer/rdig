require 'test/unit'
require 'rdig'
#File.expand_path(File.dirname(__FILE__) + "/../init.rb")
# require File.expand_path(File.dirname(__FILE__) + "/../init.rb")

module TestHelper
  include RDig

  def read_fixture(path)
    File.open("#{File.expand_path(File.dirname(__FILE__))}/fixtures/#{path}") { |f|
      f.read
    }
  end

  def word_doc(name)
    read_fixture("word/#{name}.doc")
  end
  def pdf_doc(name)
    read_fixture("pdf/#{name}.pdf")
  end
  def html_doc(name)
    read_fixture("html/#{name}.html")
  end
end
