module BayesMotel
  module Persistence
    # TODO Make this a little more Ruby idiomatic and pluggable
    # for filesystems, databases, etc.
    def self.write(corpus)
      File.open("tmp/#{corpus.name}", 'w') do |file|
        Marshal.dump(corpus, file)
      end
    end
    def self.read(name)
      Marshal.load(File.read("tmp/#{name}"))
    end
  end
end