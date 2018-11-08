require 'open3'
require 'json'
require 'base64'
require 'diffy'

# Extends the String class to add additional symbol support
class String
    def camelcase
        split.map(&:capitalize).join
    end

    def underscore
        gsub(/::/, '/')
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .tr('-', '_')
            .downcase
    end
end

class Runner
    def self.run(source)

        tests = source['tests']

        File.write(source['file'],
                   Base64.decode64(source['code']).to_s)

        results = tests.map do |test|
            symbol = test['name'].camelcase.underscore.to_sym
            expected = Base64.decode64(test['output'])
            build = 0
            build_output, build = Open3.capture2(source['build']) if source.key? 'build'
            if build == 0
                actual, = Open3.capture2(source['command'],
                                         stdin_data: Base64.decode64(test['input']))
                if actual == expected
                    [symbol, { success: true,
                               output: actual }]
                else
                    [symbol, { success: false,
                               actual: actual.to_s,
                               expected: expected.to_s,
                               difference: Diffy::Diff.new(actual, expected).to_s }]
                end
            else
                [symbol, { success: false, build: build_output }]
            end
        end
        return JSON.pretty_generate(results.to_h)
    end
end