require 'rails'

module React
  module Rails
    class Railtie < ::Rails::Railtie
      config.react = ActiveSupport::OrderedOptions.new
      config.react.max_renderers = 10
      config.react.timeout = 20 # seconds
      config.react.component_filenames = %w{ components.js }

      initializer "react_rails.setup_vendor", :after => "sprockets.environment", :group => :all do |app|
        variant = app.config.react.variant

        # Mimic behavior of ember-rails...
        # We want to include different files in dev/prod. The unminified builds
        # contain console logging for invariants and logging to help catch
        # common mistakes. These are all stripped out in the minified build.
        if variant = app.config.react.variant || ::Rails.env.test?
          variant ||= :development
          addons = app.config.react.addons || false

          # Copy over the variant into a path that sprockets will pick up.
          # We'll always copy to 'react.js' so that no includes need to change.
          # We'll also always copy of JSXTransformer.js
          tmp_path = app.root.join('tmp/react-rails')
          filename = 'react' + (addons ? '-with-addons' : '') + (variant == :production ? '.min.js' : '.js')
          FileUtils.mkdir_p(tmp_path)
          FileUtils.cp(::React::Source.bundled_path_for(filename),
                       tmp_path.join('react.js'))
          FileUtils.cp(::React::Source.bundled_path_for('JSXTransformer.js'),
                       tmp_path.join('JSXTransformer.js'))

          # Make sure it can be found
          app.assets.append_path(tmp_path)
        end

        initializer "react_rails.add_watchable_files" do |app|
          glob = "#{app.root}/app/assets/javascripts/**/*.jsx*"
          files = Dir[glob]
          app.config.watchable_files.concat(files)
        end

        config.after_initialize do |app|
          React::RendererFactory.build_and_install(app, 'Renderer')

          ActionDispatch::Reloader.to_prepare do
            React::RendererFactory.build_and_reinstall(app, 'Renderer')
          end
        end
      end
    end
  end
end
