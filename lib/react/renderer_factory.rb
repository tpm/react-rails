# encoding: UTF-8

require 'connection_pool'

module React
  class RendererFactory < Module
    attr_reader :app

    def build
      @renderer ||= Class.new.module_exec(self) do |factory|
        @factory = factory
        extend ClassMethods
        include InstanceMethods
        self
      end
    end
    alias_method :renderer, :build

    def install(name, options = {})
      namespace = options.fetch(:namespace) { React }
      namespace.module_exec(renderer) do |renderer|
        remove_const(name) if options[:replace] && const_defined?(name)
        const_set(name, renderer)
      end
    end

    def reinstall(name, options = {})
      options.merge!(replace: true)
      install(name, options)
    end

    def pool
      options = { size: react_config.max_renderers, timeout: react_config.timeout }
      ConnectionPool.new(options) { renderer.new }
    end

    def react_config
      app.config.react
    end

    def react_js_code
      File.read(app.assets.resolve('react.js'))
    end

    def components_js_code
      react_config.component_filenames.map { |name| app.assets[name].to_s }.join(?;)
    end

    private
    def initialize(app)
      @app = app
    end

    module ClassMethods
      def render(component, args={})
        pool.with do |renderer|
          renderer.render(component, args)
        end
      end

      def pool
        @pool ||= @factory.pool
      end

      def context_js_code
        @context_js_code ||= <<-CODE
          var global = global || this;
          #{@factory.react_js_code};
          React = global.React;
          #{@factory.components_js_code};
        CODE
      end
    end # ClassMethods

    module InstanceMethods
      def render(*args)
        context.eval(js_code(*args)).html_safe
      # What should be done here? If we are server rendering, and encounter an error in the JS code,
      # then log it and continue, which will just render the react ujs tag, and when the browser tries
      # to render the component it will most likely encounter the same error and throw to the browser
      # console for a better debugging experience.
      rescue ExecJS::ProgramError => e
        ::Rails.logger.error "[React::Renderer] #{e.message}"
      end

      def context
        @context ||= ExecJS.compile(self.class.context_js_code)
      end

      def js_code(component, args={})
        <<-JS
          function() {
            return React.renderComponentToString(#{component}(#{args.to_json}));
          }()
        JS
      end
    end # InstanceMethods

    class << self
      def build_and_install(app, name, options = {})
        new(app).install(name, options)
      end

      def build_and_reinstall(app, name, options = {})
        new(app).reinstall(name, options)
      end
    end # self
  end # RendererFactory
end # React