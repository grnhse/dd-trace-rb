module Datadog
  module Contrib
    module Rack
      module Patcher
        include Base
        register_as :rack
        option :tracer, default: Datadog.tracer
        option :distributed_tracing, default: false
        option :experimental_resource_name, default: false
        option :application
        option :service_name, default: 'rack', depends_on: [:tracer] do |value|
          get_option(:tracer).set_service_info(value, 'rack', Ext::AppTypes::WEB)
          value
        end

        module_function

        def patch
          return true if patched?

          require_relative 'middlewares'
          @patched = true

          return unless get_option(:experimental_resource_name)

          stack = get_option(:application) || try_rails
          patch_middleware(stack)
        end

        def patched?
          return @patched if defined?(@patched)
          @patched
        end

        def try_rails
          return unless Datadog.registry[:rails].compatible?
          ::Rails.application.app
        end

        def patch_middleware(middleware)
          return unless middleware && middleware.respond_to?(:call)

          middleware.class_eval do
            alias_method :__call, :call

            def call(env)
              env['LAST_MIDDLEWARE_HIT'] = self.class.to_s
              __call(env)
            end
          end

          following = middleware.instance_variable_get('@app')
          patch_middleware(following)
        end
      end
    end
  end
end
