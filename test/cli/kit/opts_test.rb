require 'test_helper'

module CLI
  module Kit
    class OptsTest < Minitest::Test
      class TestOpts < CLI::Kit::Opts
        def force
          flag(short: '-f', long: '--force', desc: 'Force')
        end

        def output
          option!(short: '-o', long: '--output', default: 'text')
        end

        def file
          option(long: '--file')
        end

        def args
          rest
        end
      end

      module FirstMixin
        include(CLI::Kit::Opts::Mixin)

        def first
          position!
        end
      end

      module MixinMixin
        include(CLI::Kit::Opts::Mixin)

        def penultimate
          position!
        end
      end

      module LastMixin
        include(CLI::Kit::Opts::Mixin)
        include(MixinMixin)

        def last
          position!
        end
      end

      class OrderOpts < CLI::Kit::Opts
        include(FirstMixin)

        def middle
          position!
        end

        include(LastMixin)
      end

      def test_stuff
        defn = Args::Definition.new
        TestOpts.new(defn).install_to_definition
        evl = evaluate(defn, '-f -o json test -- a b')
        opts = TestOpts.new(evl)
        assert(opts.force)
        assert_equal('json', opts.output)
        refute(opts.file)
        assert_equal(['test'], opts.args)
        assert_equal(['a', 'b'], opts.unparsed)

        assert_equal({ output: 'json', file: nil }, opts.each_option.to_h)
        assert_equal({ force: true, help: false }, opts.each_flag.to_h)

        assert_equal('json', opts.lookup_option('output'))
        assert_equal(true, opts.lookup_flag('force'))

        refute(opts.lookup_option('force'))
        refute(opts.lookup_flag('output'))
        refute(opts.lookup_flag('foobar'))

        assert_equal('json', opts['output'])
        assert_equal(true, opts['force'])
      end

      def test_order
        defn = Args::Definition.new
        OrderOpts.new(defn).install_to_definition
        evl = evaluate(defn, 'a b c d')
        opts = OrderOpts.new(evl)
        assert_equal('a', opts.first)
        assert_equal('b', opts.middle)
        assert_equal('c', opts.penultimate)
        assert_equal('d', opts.last)
      end

      private

      def evaluate(defn, str)
        tokens = Args::Tokenizer.tokenize(str.split(' '))
        parse = Args::Parser.new(defn).parse(tokens)
        Args::Evaluation.new(defn, parse)
      end
    end
  end
end
