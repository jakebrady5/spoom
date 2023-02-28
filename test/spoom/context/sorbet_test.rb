# typed: true
# frozen_string_literal: true

require "test_helper"

module Spoom
  class Context
    class SorbetTest < Minitest::Test
      def test_context_write_sorbet_config!
        context = Context.mktmp!

        assert_raises(Errno::ENOENT) do
          context.read_sorbet_config
        end

        context.write_sorbet_config!(".")
        assert_equal(".", context.read_sorbet_config)

        context.destroy!
      end

      def test_context_srb
        context = Context.mktmp!

        context.write!("a.rb", <<~RB)
          # typed: true

          foo(42)
        RB

        res = context.srb("tc")
        refute(res.status)

        context.write_gemfile!(<<~GEMFILE)
          source "https://rubygems.org"

          gem "sorbet"
        GEMFILE
        context.bundle_install!

        res = context.srb("tc")
        refute(res.status)

        context.write_sorbet_config!(".")
        res = context.srb("tc")
        assert_equal(<<~ERR, res.err)
          a.rb:3: Method `foo` does not exist on `T.class_of(<root>)` https://srb.help/7003
               3 |foo(42)
                  ^^^
          Errors: 1
        ERR
        refute(res.status)

        context.write!("b.rb", <<~RB)
          def foo(value); end
        RB

        res = context.srb("tc")
        assert(res.status)

        context.destroy!
      end

      def test_context_file_strictness
        context = Context.mktmp!

        assert_nil(context.read_file_strictness("a.rb"))

        context.write!("a.rb", "")
        assert_nil(context.read_file_strictness("a.rb"))

        context.write!("a.rb", "# typed: true\n")
        assert_equal("true", context.read_file_strictness("a.rb"))

        context.destroy!
      end

      def test_context_sorbet_intro_not_found
        context = Context.mktmp!
        context.git_init!
        context.git("config user.name 'John Doe'")
        context.git("config user.email 'john@doe.org'")

        assert_nil(context.sorbet_intro_commit)

        context.destroy!
      end

      def test_context_sorbet_intro_found
        intro_time = Time.parse("1987-02-05 09:00:00 +0000")
        context = Context.mktmp!
        context.git_init!
        context.git("config user.name 'John Doe'")
        context.git("config user.email 'john@doe.org'")
        context.write!("sorbet/config")
        context.git_commit!(time: intro_time)

        commit = context.sorbet_intro_commit
        assert_match(/\A[a-z0-9]+\z/, commit&.sha)
        assert_equal(intro_time, commit&.time)

        context.destroy!
      end

      def test_context_sorbet_removal_not_found
        context = Context.mktmp!
        context.git_init!
        context.git("config user.name 'John Doe'")
        context.git("config user.email 'john@doe.org'")

        assert_nil(context.sorbet_removal_commit)

        context.destroy!
      end

      def test_context_sorbet_removal_found
        intro_time = Time.parse("1987-02-05 09:00:00 +0000")
        removal_time = Time.parse("1987-02-05 21:00:00 +0000")
        context = Context.mktmp!
        context.git_init!
        context.git("config user.name 'John Doe'")
        context.git("config user.email 'john@doe.org'")
        context.write!("sorbet/config")
        context.git_commit!(time: intro_time)
        context.remove!("sorbet/config")
        context.git_commit!(time: removal_time)

        commit = context.sorbet_removal_commit
        assert_match(/\A[a-z0-9]+\z/, commit&.sha)
        assert_equal(removal_time, commit&.time)

        context.destroy!
      end
    end
  end
end
