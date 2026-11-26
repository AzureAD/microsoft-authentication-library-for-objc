#!/usr/bin/env ruby

# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Broker-style exports from existing MSAL tests, not additional coverage runs.
# Each framework keeps its executed slice/profile and its own Cobertura XML.
# Completeness checks fail explicitly without deleting other valid reports.
require 'json'
require 'open3'
require 'fileutils'
require 'digest'
require 'rexml/document'

module MSALCoverage
  EXPECTED_SCHEMES = {
    'iosFramework' => ['MSAL (iOS Framework)'],
    'macFramework' => ['MSAL (Mac Framework)']
  }.freeze
  PROJECT = 'MSAL/MSAL.xcodeproj'.freeze

  def self.run(*command)
    puts command.map(&:inspect).join(' ')
    stdout, stderr, status = Open3.capture3(*command)
    warn stderr unless stderr.empty?
    raise "#{command.first} failed (#{status.exitstatus}): #{stderr}" unless status.success?
    raise "Coverage inputs do not match: #{stderr}" if stderr.match?(/profile data may be out of date|mismatched/i)
    stdout
  end

  def self.executed_architecture(result)
    actions = result.fetch('actions').fetch('_values').select do |action|
      action.fetch('actionResult', {}).key?('testsRef')
    end
    architectures = actions.map { |action| action.dig('runDestination', 'targetArchitecture', '_value') }.uniq
    unless architectures.length == 1 && architectures.first && !architectures.first.empty?
      raise "Expected one executed test architecture, found #{architectures.inspect}"
    end
    architectures.first
  end

  def self.production_products(scheme)
    document = REXML::Document.new(File.read(scheme))
    products = REXML::XPath.match(document, '//TestAction/CodeCoverageTargets/BuildableReference')
    if products.empty?
      products = REXML::XPath.match(document, '//BuildActionEntry[@buildForTesting="YES"]/BuildableReference')
    end
    products.map { |node| node.attributes.fetch('BuildableName').to_s }
            .reject { |name| name.end_with?('.xctest') }.uniq
  end

  def self.validate_report(path)
    document = REXML::Document.new(File.read(path))
    unless document.root&.name == 'coverage' &&
           document.root.attributes['lines-valid'].to_i > 0 &&
           !REXML::XPath.match(document, '//class/lines/line').empty?
      raise "Missing executable source coverage in #{path}"
    end
    document
  end

  def self.export(scheme, derived_data, result_bundle, root: 'build/coverage', project_path: PROJECT)
    output = File.join(root, 'reports', scheme)
    diagnostics = File.join(root, 'diagnostics', scheme)
    FileUtils.mkdir_p([output, diagnostics])
    report = File.join(output, "#{scheme}.cobertura.xml")
    FileUtils.rm_f(report)
    provenance = {
      'scheme' => scheme, 'derived_data' => File.expand_path(derived_data),
      'result_bundle' => File.expand_path(result_bundle), 'status' => 'failed'
    }

    begin
      raise "Unexpected coverage scheme #{scheme}" unless EXPECTED_SCHEMES.values.flatten.include?(scheme)
      require 'slather'
      provenance['slather'] = Slather::VERSION
      metadata = run('xcrun', 'xcresulttool', 'get', 'object', '--legacy',
                     '--path', result_bundle, '--format', 'json')
      File.write(File.join(diagnostics, 'result.json'), metadata)
      architecture = executed_architecture(JSON.parse(metadata))
      provenance['architecture'] = architecture
      profiles = Dir[File.join(derived_data, 'Build/ProfileData/*/Coverage.profdata')]
      raise "Expected exactly one profile for #{scheme}, found #{profiles.inspect}" unless profiles.length == 1
      profile = File.realpath(profiles.first)
      provenance['profile'] = { 'path' => profile, 'sha256' => Digest::SHA256.file(profile).hexdigest }
      provenance['revision'] = run('git', 'rev-parse', 'HEAD').strip
      native_json = run('xcrun', 'xccov', 'view', '--report', '--json', result_bundle)
      File.write(File.join(diagnostics, 'xccov.json'), native_json)
      native = JSON.parse(native_json)

      project = Slather::Project.open(project_path)
      project.workspace = 'MSAL.xcworkspace'
      project.scheme = scheme
      project.configuration = 'Debug'
      project.build_directory = File.expand_path(derived_data)
      project.arch = architecture
      project.input_format = 'profdata'
      project.coverage_service = :cobertura_xml
      project.output_directory = output
      scheme_path = File.join(project_path, 'xcshareddata/xcschemes', "#{scheme}.xcscheme")
      products = production_products(scheme_path)
      # The existing tested MSAL schemes are dynamic frameworks. Do not silently
      # substitute a test payload or invent coverage for build-only static targets.
      raise "Expected MSAL.framework in #{scheme}, found #{products.inspect}" unless products == ['MSAL.framework']
      project.binary_basename = products
      project.configure
      raise "Slather selected a different profile for #{scheme}" unless File.realpath(project.send(:profdata_file)) == profile
      raise "Expected one production binary for #{scheme}" unless project.binary_file.length == 1
      binary = File.realpath(project.binary_file.first)
      products_directory = File.realpath(File.join(derived_data, 'Build/Products')) + File::SEPARATOR
      raise "Production binary outside scheme-local products: #{binary}" unless binary.start_with?(products_directory)
      architectures = run('xcrun', 'lipo', '-archs', binary).split
      provenance['binaries'] = [{ 'path' => binary, 'architectures' => architectures,
                                 'sha256' => Digest::SHA256.file(binary).hexdigest }]
      raise "#{binary} does not contain executed architecture #{architecture}" unless architectures.include?(architecture)
      targets = native.fetch('targets').select do |target|
        path = target.fetch('buildProductPath')
        File.file?(path) && File.realpath(path) == binary
      end
      raise "Expected one native production target for #{binary}" unless targets.length == 1

      checkout = File.realpath('.')
      # MSAL.framework includes IdentityCore and a test utility. Only tracked
      # MSAL/src files belong to this SDK's report; never filter by name or hits.
      tracked = run('git', 'ls-files', '-z', '--', 'MSAL/src').split("\0").to_h do |path|
        [File.expand_path(path, checkout), true]
      end
      sources = targets.first.fetch('files').select { |file| file.fetch('executableLines') > 0 }.map do |file|
        path = file.fetch('path')
        File.realpath(path) if File.file?(path)
      end.compact.select { |path| tracked.key?(path) }.uniq
      raise "No native tracked production sources for #{scheme}" if sources.empty?
      data = run('xcrun', 'llvm-cov', 'export', '-instr-profile', profile, '--arch', architecture, binary)
      File.write(File.join(diagnostics, 'binary.json'), data)
      unless JSON.parse(data).fetch('data').any? { |chunk| !chunk.fetch('files').empty? }
        raise "No coverage mapping in #{binary}"
      end
      # xccov selects production files, never substitutes its counts for LLVM.
      files = project.coverage_files.select do |file|
        path = file.source_file_pathname
        path.file? && sources.include?(path.realpath.to_s)
      end
      missing = sources - files.map { |file| file.source_file_pathname.realpath.to_s }
      raise "Missing native production source mappings: #{missing.inspect}" unless missing.empty?
      project.store_report(project.create_xml_report(files))
      FileUtils.mv(File.join(output, 'cobertura.xml'), report)
      validate_report(report)
      provenance['status'] = 'complete'
      puts "Collected #{scheme}: #{files.length} tracked production sources -> #{report}"
    rescue StandardError, LoadError => error
      provenance['error'] = error.message
      FileUtils.rm_f(report)
      raise
    ensure
      File.write(File.join(diagnostics, 'provenance.json'), JSON.pretty_generate(provenance))
    end
  end

  def self.verify(target, root: 'build/coverage')
    errors = []
    EXPECTED_SCHEMES.fetch(target).each do |scheme|
      begin
        validate_report(File.join(root, 'reports', scheme, "#{scheme}.cobertura.xml"))
        provenance = JSON.parse(File.read(File.join(root, 'diagnostics', scheme, 'provenance.json')))
        raise "Collection did not complete for #{scheme}" unless provenance.fetch('status') == 'complete'
      rescue StandardError => error
        errors << "#{scheme}: #{error.message}"
      end
    end
    raise errors.join("\n") unless errors.empty?
  end

  def self.verify_publication(root)
    errors = []
    EXPECTED_SCHEMES.values.flatten.each do |scheme|
      begin
        reports = Dir[File.join(root, '**', "#{scheme}.cobertura.xml")]
        raise "Expected one retained report, found #{reports.length}" unless reports.length == 1
        validate_report(reports.first)
        yield reports.first, scheme if block_given?
      rescue StandardError => error
        errors << "#{scheme}: #{error.message}"
      end
    end
    raise errors.join("\n") unless errors.empty?
  end

  def self.prepare_publication(root, output, checkout: '.')
    root = File.realpath(root)
    checkout = File.realpath(checkout)
    output = File.exist?(output) ? File.realpath(output) : File.expand_path(output)
    if output == root || output.start_with?(root + '/') || root.start_with?(output + '/')
      raise 'Publication copies must be separate from retained reports'
    end
    FileUtils.mkdir_p(output)
    EXPECTED_SCHEMES.values.flatten.each { |scheme| FileUtils.rm_f(File.join(output, "#{scheme}.cobertura.xml")) }
    tracked = run('git', '-C', checkout, 'ls-files', '-z', '--', 'MSAL/src').split("\0").to_h { |path| [path, true] }
    verify_publication(root) do |report, scheme|
      document = validate_report(report)
      REXML::XPath.each(document, '//class') do |node|
        path = node.attributes['filename'].to_s
        unless path.start_with?('MSAL/src/') && !path.include?('\\') &&
               path.split('/', -1).none? { |part| ['', '.', '..'].include?(part) } && tracked.key?(path)
          raise "Unowned or noncanonical production source: #{path.inspect}"
        end
        source = File.join(checkout, path)
        raise "Missing publication source: #{path}" unless File.file?(source)
        resolved = File.realpath(source)
        unless resolved.start_with?(File.join(checkout, 'MSAL/src/')) &&
               tracked.key?(resolved.delete_prefix(checkout + '/'))
          raise "Publication source escapes tracked production files: #{path}"
        end
      end
      # Producer and publisher agents can use different checkout roots. Change
      # only the source root, never filenames, counts, or the retained handoff.
      document.root.elements.delete_all('sources')
      sources = REXML::Element.new('sources')
      sources.add_element('source').text = checkout
      document.root.insert_before(document.root.elements[1], sources)
      destination = File.join(output, "#{scheme}.cobertura.xml")
      File.write(destination, document.to_s)
      puts "Prepared #{scheme} for publication from #{checkout} -> #{destination}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    case ARGV.shift
    when 'export'
      raise 'Usage: coverage.rb export SCHEME DERIVED_DATA RESULT_BUNDLE' unless ARGV.length == 3
      MSALCoverage.export(*ARGV)
    when 'verify'
      raise 'Usage: coverage.rb verify BUILD_TARGET' unless ARGV.length == 1
      MSALCoverage.verify(ARGV.first)
    when 'verify-publication'
      raise 'Usage: coverage.rb verify-publication REPORT_ROOT' unless ARGV.length == 1
      MSALCoverage.verify_publication(ARGV.first)
    when 'prepare-publication'
      raise 'Usage: coverage.rb prepare-publication REPORT_ROOT OUTPUT' unless ARGV.length == 2
      MSALCoverage.prepare_publication(*ARGV)
    else
      raise 'Usage: coverage.rb export|verify|verify-publication|prepare-publication ...'
    end
  rescue StandardError, LoadError => error
    warn "##vso[task.logissue type=error]Coverage collection failed: #{error.message}"
    warn error.backtrace.join("\n")
    exit 1
  end
end
