# typed: true
require 'cli/kit'

module CLI
  module Kit
    module Args
      class Definition
        extend T::Sig

        Error = Class.new(Args::Error)
        ConflictingFlag = Class.new(Error)
        InvalidFlag = Class.new(Error)
        InvalidLookup = Class.new(Error)

        sig { returns(T::Array[Flag]) }
        attr_reader :flags

        sig { returns(T::Array[Option]) }
        attr_reader :options

        sig { params(name: Symbol, short: T.nilable(String), long: T.nilable(String), desc: T.nilable(String)).void }
        def add_flag(name, short: nil, long: nil, desc: nil)
          short, long = strip_prefixes_and_validate(short, long)
          flag = Flag.new(name: name, short: short, long: long, desc: desc)
          add_resolution(flag)
          @flags << flag
        end

        sig do
          params(
            name: Symbol, short: T.nilable(String), long: T.nilable(String),
            desc: T.nilable(String), default: T.any(NilClass, String, T.proc.returns(String)),
            required: T::Boolean, multi: T::Boolean,
          ).void
        end
        def add_option(name, short: nil, long: nil, desc: nil, default: nil, required: false, multi: false)
          short, long = strip_prefixes_and_validate(short, long)
          option = Option.new(
            name: name, short: short, long: long, desc: desc, default: default,
            required: required, multi: multi,
          )
          add_resolution(option)
          @options << option
        end

        sig { void }
        def initialize
          @flags = []
          @options = []
          @by_short = {}
          @by_long = {}
          @by_name = {}
        end

        class Flag
          extend T::Sig

          sig { returns(Symbol) }
          attr_reader :name

          sig { returns(T.nilable(String)) }
          attr_reader :short

          sig { returns(T.nilable(String)) }
          attr_reader :long

          sig { returns(T.nilable(String)) }
          attr_reader :desc

          sig { returns(String) }
          def as_written_by_user
            long ? "--#{long}" : "-#{short}"
          end

          sig { params(name: Symbol, short: T.nilable(String), long: T.nilable(String), desc: T.nilable(String)).void }
          def initialize(name:, short: nil, long: nil, desc: nil)
            if long&.start_with?('-') || short&.start_with?('-')
              raise(ArgumentError, 'invalid - prefix')
            end
            @name = name
            @short = short
            @long = long
            @desc = desc
          end
        end

        class Option < Flag
          extend T::Sig

          sig { returns(T.nilable(String)) }
          def default
            if @default.is_a?(Proc)
              @default.call
            else
              @default
            end
          end

          sig { returns(T::Boolean) }
          def dynamic_default?
            @default.is_a?(Proc)
          end

          sig { returns(T::Boolean) }
          attr_reader :required

          sig { returns(T::Boolean) }
          attr_reader :multi

          sig do
            params(
              name: Symbol, short: T.nilable(String), long: T.nilable(String),
              desc: T.nilable(String), default: T.any(NilClass, String, T.proc.returns(String)),
              required: T::Boolean, multi: T::Boolean,
            ).void
          end
          def initialize(name:, short: nil, long: nil, desc: nil, default: nil, required: false, multi: false)
            if multi && (default || required)
              raise(ArgumentError, 'multi-valued options cannot have a default or required value')
            end

            super(name: name, short: short, long: long, desc: desc)
            @default = default
            @required = required
            @multi = multi
          end
        end

        sig { params(name: Symbol).returns(T.nilable(Flag)) }
        def lookup_flag(name)
          flagopt = @by_name[name]
          if flagopt.class == Flag
            flagopt
          end
        end

        sig { params(name: Symbol).returns(T.nilable(Option)) }
        def lookup_option(name)
          flagopt = @by_name[name]
          if flagopt.class == Option
            flagopt
          end
        end

        sig { params(name: String).returns(T.any(Flag, Option, NilClass)) }
        def lookup_short(name)
          raise(InvalidLookup, "invalid '-' prefix") if name.start_with?('-')
          @by_short[name]
        end

        sig { params(name: String).returns(T.any(Flag, Option, NilClass)) }
        def lookup_long(name)
          raise(InvalidLookup, "invalid '-' prefix") if name.start_with?('-')
          @by_long[name]
        end

        private

        sig { params(short: String).returns(String) }
        def strip_short_prefix(short)
          unless short.match?(/^-[^-]/)
            raise(InvalidFlag, "Short flag '#{short}' does not start with '-'")
          end
          if short.size != 2
            raise(InvalidFlag, 'Short flag must be a single character')
          end
          short.sub(/^-/, '')
        end

        sig { params(long: String).returns(String) }
        def strip_long_prefix(long)
          unless long.match?(/^--[^-]/)
            raise(InvalidFlag, "Long flag '#{long}' does not start with '--'")
          end
          long.sub(/^--/, '')
        end

        sig do
          params(short: T.nilable(String), long: T.nilable(String))
            .returns([T.nilable(String), T.nilable(String)])
        end
        def strip_prefixes_and_validate(short, long)
          if short.nil? && long.nil?
            raise(Error, 'One or more of short and long must be specified')
          end

          short = strip_short_prefix(short) if short
          long = strip_long_prefix(long) if long

          [short, long]
        end

        sig { params(flagopt: Flag).void }
        def add_resolution(flagopt)
          if flagopt.short
            if (existing = @by_short[flagopt.short])
              raise(ConflictingFlag, "Short flag '#{flagopt.short}' already defined by #{existing.name}")
            end
            @by_short[flagopt.short] = flagopt
          end
          if flagopt.long
            if (existing = @by_long[flagopt.long])
              raise(ConflictingFlag, "Long flag '#{flagopt.long}' already defined by #{existing.name}")
            end
            @by_long[flagopt.long] = flagopt
          end
          if (existing = @by_name[flagopt.name])
            raise(ConflictingFlag, "Flag '#{flagopt.name}' already defined by #{existing.name}")
          end
          @by_name[flagopt.name] = flagopt
        end
      end
    end
  end
end
