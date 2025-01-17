# typed: strict
# frozen_string_literal: true

require "set"

module Spoom
  module Deadcode
    module Plugins
      class Base
        extend T::Sig
        extend T::Helpers

        abstract!

        class << self
          extend T::Sig

          # Plugins DSL

          # Mark methods matching `names` as ignored.
          #
          # Names can be either strings or regexps:
          #
          # ~~~rb
          # class MyPlugin < Spoom::Deadcode::Plugins::Base
          #   ignore_method_names(
          #     "foo",
          #     "bar",
          #     /baz.*/,
          #   )
          # end
          # ~~~
          sig { params(names: T.any(String, Regexp)).void }
          def ignore_method_names(*names)
            save_names_and_patterns(names, :@ignored_method_names, :@ignored_method_patterns)
          end

          private

          sig { params(names: T::Array[T.any(String, Regexp)], names_variable: Symbol, patterns_variable: Symbol).void }
          def save_names_and_patterns(names, names_variable, patterns_variable)
            ignored_names = instance_variable_set(names_variable, Set.new)
            ignored_patterns = instance_variable_set(patterns_variable, [])

            names.each do |name|
              case name
              when String
                ignored_names << name
              when Regexp
                ignored_patterns << name
              end
            end
          end
        end

        # Indexing event methods

        # Called when an accessor is defined.
        #
        # Will be called when the indexer processes a `attr_reader`, `attr_writer` or `attr_accessor` node.
        # Note that when this method is called, the definition for the node has already been added to the index.
        # It is still possible to ignore it from the plugin:
        #
        # ~~~rb
        # class MyPlugin < Spoom::Deadcode::Plugins::Base
        #   def on_define_accessor(indexer, definition)
        #     definition.ignored! if definition.name == "foo"
        #   end
        # end
        # ~~~
        sig { params(indexer: Indexer, definition: Definition).void }
        def on_define_accessor(indexer, definition)
          # no-op
        end

        # Called when a class is defined.
        #
        # Will be called when the indexer processes a `class` node.
        # Note that when this method is called, the definition for the node has already been added to the index.
        # It is still possible to ignore it from the plugin:
        #
        # ~~~rb
        # class MyPlugin < Spoom::Deadcode::Plugins::Base
        #   def on_define_class(indexer, definition)
        #     definition.ignored! if definition.name == "Foo"
        #   end
        # end
        # ~~~
        sig { params(indexer: Indexer, definition: Definition).void }
        def on_define_class(indexer, definition)
          # no-op
        end

        # Called when a constant is defined.
        #
        # Will be called when the indexer processes a `CONST =` node.
        # Note that when this method is called, the definition for the node has already been added to the index.
        # It is still possible to ignore it from the plugin:
        #
        # ~~~rb
        # class MyPlugin < Spoom::Deadcode::Plugins::Base
        #   def on_define_constant(indexer, definition)
        #     definition.ignored! if definition.name == "FOO"
        #   end
        # end
        # ~~~
        sig { params(indexer: Indexer, definition: Definition).void }
        def on_define_constant(indexer, definition)
          # no-op
        end

        # Called when a method is defined.
        #
        # Will be called when the indexer processes a `def` or `defs` node.
        # Note that when this method is called, the definition for the node has already been added to the index.
        # It is still possible to ignore it from the plugin:
        #
        # ~~~rb
        # class MyPlugin < Spoom::Deadcode::Plugins::Base
        #   def on_define_method(indexer, definition)
        #     super # So the `ignore_method_names` DSL is still applied
        #
        #     definition.ignored! if definition.name == "foo"
        #   end
        # end
        # ~~~
        sig { params(indexer: Indexer, definition: Definition).void }
        def on_define_method(indexer, definition)
          definition.ignored! if ignored_method_name?(definition.name)
        end

        # Called when a module is defined.
        #
        # Will be called when the indexer processes a `module` node.
        # Note that when this method is called, the definition for the node has already been added to the index.
        # It is still possible to ignore it from the plugin:
        #
        # ~~~rb
        # class MyPlugin < Spoom::Deadcode::Plugins::Base
        #   def on_define_module(indexer, definition)
        #     definition.ignored! if definition.name == "Foo"
        #   end
        # end
        # ~~~
        sig { params(indexer: Indexer, definition: Definition).void }
        def on_define_module(indexer, definition)
          # no-op
        end

        # Called when a send is being processed
        #
        # ~~~rb
        # class MyPlugin < Spoom::Deadcode::Plugins::Base
        #   def on_send(indexer, send)
        #     return unless send.name == "dsl_method"
        #     return if send.args.empty?
        #
        #     method_name = indexer.node_string(send.args.first).delete_prefix(":")
        #     indexer.reference_method(method_name, send.node)
        #   end
        # end
        # ~~~
        sig { params(indexer: Indexer, send: Send).void }
        def on_send(indexer, send)
          # no-op
        end

        private

        sig { params(name: String).returns(T::Boolean) }
        def ignored_method_name?(name)
          ignored_name?(name, :@ignored_method_names, :@ignored_method_patterns)
        end

        sig { params(const: Symbol).returns(T::Set[String]) }
        def names(const)
          self.class.instance_variable_get(const) || Set.new
        end

        sig { params(name: String, names_variable: Symbol, patterns_variable: Symbol).returns(T::Boolean) }
        def ignored_name?(name, names_variable, patterns_variable)
          names(names_variable).include?(name) || patterns(patterns_variable).any? { |pattern| pattern.match?(name) }
        end

        sig { params(const: Symbol).returns(T::Array[Regexp]) }
        def patterns(const)
          self.class.instance_variable_get(const) || []
        end

        sig { params(indexer: Indexer, send: Send).void }
        def reference_send_first_symbol_as_method(indexer, send)
          first_arg = send.args.first
          return unless first_arg.is_a?(SyntaxTree::SymbolLiteral)

          name = indexer.node_string(first_arg.value)
          indexer.reference_method(name, send.node)
        end
      end
    end
  end
end
