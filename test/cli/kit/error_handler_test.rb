require 'test_helper'
require 'tempfile'

module CLI
  module Kit
    class ErrorHandlerTest < Minitest::Test
      class MockExceptionReporter < ErrorHandler::ExceptionReporter
        def self.report(_exception, _logs = nil); end
      end

      def setup
        @rep = MockExceptionReporter
        @tf  = Tempfile.create('executor-log').tap(&:close)
        @eh = error_handler
      end

      def teardown
        File.unlink(@tf.path)
      end

      def test_success
        run_test(
          expect_code:   CLI::Kit::EXIT_SUCCESS,
          expect_out:    "neato\n",
          expect_err:    '',
          expect_report: false,
        ) do
          puts 'neato'
        end
      end

      def test_abort_silent
        run_test(
          expect_code:   CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG,
          expect_out:    '',
          expect_err:    '',
          expect_report: false,
        ) do
          raise(CLI::Kit::AbortSilent)
        end
      end

      def test_abort
        run_test(
          expect_code:   CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG,
          expect_out:    '',
          expect_err:    /foo/,
          expect_report: false,
        ) do
          raise(CLI::Kit::Abort, 'foo')
        end
      end

      def test_bug_silent
        File.write(@tf.path, 'words')
        run_test(
          expect_code:   CLI::Kit::EXIT_BUG,
          expect_out:    '',
          expect_err:    '',
          expect_report: [is_a(CLI::Kit::BugSilent), 'words'],
        ) do
          raise(CLI::Kit::BugSilent)
        end
      end

      def test_bug
        run_test(
          expect_code:   CLI::Kit::EXIT_BUG,
          expect_out:    '',
          expect_err:    /foo/,
          expect_report: [is_a(CLI::Kit::Bug), ''],
        ) do
          raise(CLI::Kit::Bug, 'foo')
        end
      end

      def test_out_of_space
        run_test(
          expect_code:   CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG,
          expect_out:    '',
          expect_err:    "\e[0;31mYour disk is full - free space is required to operate\e[0m\n",
          expect_report: false,
        ) do
          raise(Errno::ENOSPC)
        end
      end

      def test_out_of_space_with_name
        @eh = error_handler(tool_name: 'foo')
        run_test(
          expect_code:   CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG,
          expect_out:    '',
          expect_err:    "\e[0;31mYour disk is full - \e[0;31;36mfoo\e[0;31m requires free space to operate\e[0m\n",
          expect_report: false,
        ) do
          raise(Errno::ENOSPC)
        end
      end

      def test_interrupt
        run_test(
          expect_code:   CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG,
          expect_out:    '',
          expect_err:    /Interrupt/,
          expect_report: false,
        ) do
          raise(Interrupt)
        end
      end

      def test_arbitrary
        run_test(
          expect_code:   CLI::Kit::EXIT_BUG,
          expect_out:    '',
          expect_err:    "\e[0;31mwups\e[0m\n",
          expect_report: [is_a(RuntimeError), ''],
        ) do
          raise('wups')
        end
      end

      def test_dev_mode_bugs_reraise
        @eh = error_handler(dev_mode: true)
        run_test(
          expect_code:   :unhandled,
          expect_out:    '',
          expect_err:    '',
          expect_report: [is_a(RuntimeError), ''],
        ) do
          raise('wups')
        end
      end

      def test_dev_mode_aborts_dont_change_behaviour
        @eh = error_handler(dev_mode: true)
        run_test(
          expect_code:   CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG,
          expect_out:    '',
          expect_err:    /foo/,
          expect_report: false,
        ) do
          raise(CLI::Kit::Abort, 'foo')
        end
      end

      def test_override_exception_handler
        @eh = error_handler(dev_mode: true)

        exc = nil
        @eh.override_exception_handler = ->(e) do
          puts('out')
          $stderr.puts('err')
          exc = e
          42
        end

        run_test(
          expect_code:   42,
          expect_out:    "out\n",
          expect_err:    "err\n",
          expect_report: [is_a(RuntimeError), ''],
        ) do
          raise('a bug')
        end

        assert_equal('a bug', exc.message)
      end

      # the rest of these are hard because they kind of rely on the handler
      # actually running in at_exit.

      def test_non_bug_signal
        # e.g. SIGTERM
        skip
      end

      def test_bug_signal
        # e.g. SIGSEGV
        skip
      end

      def test_exit_0
        skip
      end

      def test_exit_30
        skip
      end

      def test_exit_1
        skip
      end

      private

      def error_handler(tool_name: nil, dev_mode: false)
        ErrorHandler.new(
          log_file: @tf.path, exception_reporter: @rep, tool_name: tool_name, dev_mode: dev_mode,
        ).tap do |eh|
          class << eh
            attr_reader :exit_handler

            # Prevent `install!` from actually installing the hook.
            def at_exit(&block)
              @exit_handler = block
            end
          end
        end
      end

      def with_handler(&block)
        code = nil
        out, err = capture_io do
          code = @eh.call(&block)
        rescue => e
          # This is cheating, but it's the easiest way I could think of to
          # work around not wanting to actually have to call an at_exit
          # handler with $ERROR_INFO here.
          @eh.instance_variable_set(:@exception, e)
          code = :unhandled
        ensure
          @eh.exit_handler.call
        end
        [out, err, code]
      end

      def run_test(expect_code:, expect_out:, expect_err:, expect_report:, &block)
        if expect_report
          @rep.expects(:report).once.with(*expect_report)
        else
          @rep.expects(:report).never
        end
        out, err, code = with_handler(&block)
        assert_equal(expect_out, out)
        if expect_err.is_a?(Regexp)
          assert_match(expect_err, err)
        else
          assert_equal(expect_err, err)
        end
        assert_equal(expect_code, code)
      end
    end
  end
end
