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

# No SDK builds or XCTest runs: fixtures cover input selection and publication
# failures. The opt-in LLVM test compiles only a tiny standalone C fixture.
require 'minitest/autorun'
require 'tmpdir'
require 'pathname'
require 'slather'
require 'yaml'
require_relative '../coverage'

class CoverageTests < Minitest::Test
  REPO = File.expand_path('../..', __dir__)
  IOS = 'MSAL (iOS Framework)'.freeze
  MAC = 'MSAL (Mac Framework)'.freeze
  REPORT = '<coverage line-rate="0" lines-valid="1" lines-covered="0"><packages><package name="MSAL"><classes>' \
           '<class name="owned" filename="MSAL/src/owned.m"><lines><line number="1" hits="0"/></lines></class>' \
           '</classes></package></packages></coverage>'

  class ProjectStub
    attr_accessor :workspace, :scheme, :configuration, :build_directory, :arch,
                  :input_format, :coverage_service, :output_directory, :binary_basename,
                  :binary_file, :coverage_files, :profile, :exported_files
    def configure; end
    def profdata_file
      profile
    end
    def create_xml_report(files)
      self.exported_files = files
      REPORT
    end
    def store_report(report)
      File.write(File.join(output_directory, 'cobertura.xml'), report)
    end
  end

  def setup
    @directory = File.realpath(Dir.mktmpdir('msal-coverage-test'))
    @root = File.join(@directory, 'coverage')
    @derived = File.join(@directory, 'derived data')
    @profile = File.join(@derived, 'Build/ProfileData/device/Coverage.profdata')
    @binary = File.join(@derived, 'Build/Products/Debug/MSAL.framework/MSAL')
    [@profile, @binary].each do |file|
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, 'fixture')
    end
    @owned = Pathname(File.join(@directory, 'owned.m'))
    @zero = Pathname(File.join(@directory, 'zero.swift'))
    @generated = Pathname(File.join(@derived, 'GeneratedAssetSymbols.swift'))
    [@owned, @zero, @generated].each { |file| file.write('source') }
    @project = ProjectStub.new
    @project.profile = @profile
    @project.binary_file = [@binary]
    @project.coverage_files = [@owned, @zero, @generated].map do |path|
      Struct.new(:source_file_pathname).new(path)
    end
    @commands = []
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def result(*architectures)
    { 'actions' => { '_values' => architectures.map do |architecture|
      { 'actionResult' => { 'testsRef' => {} },
        'runDestination' => { 'targetArchitecture' => { '_value' => architecture } } }
    end } }
  end

  def command_result(*command)
    @commands << command
    return 'fixture-revision' if command == ['git', 'rev-parse', 'HEAD']
    return "#{@owned.realpath}\0#{@zero.realpath}\0" if command == ['git', 'ls-files', '-z', '--', 'MSAL/src']
    case command[1]
    when 'xcresulttool' then JSON.generate(result('arm64'))
    when 'xccov'
      JSON.generate('targets' => [{ 'buildProductPath' => @binary,
                                   'files' => [@owned, @zero, @generated].map do |path|
                                     { 'path' => path.to_s, 'executableLines' => 1, 'coveredLines' => 0 }
                                   end }])
    when 'lipo' then 'x86_64 arm64'
    when 'llvm-cov' then '{"data":[{"files":[{"filename":"owned.m"}]}]}'
    else raise "Unexpected command: #{command.inspect}"
    end
  end

  def export(scheme = IOS, command: method(:command_result))
    Slather::Project.stub(:open, @project) do
      MSALCoverage.stub(:run, command) do
        MSALCoverage.export(scheme, @derived, 'result.xcresult', root: @root,
                            project_path: File.join(REPO, MSALCoverage::PROJECT))
      end
    end
  end

  def provenance(scheme = IOS)
    JSON.parse(File.read(File.join(@root, 'diagnostics', scheme, 'provenance.json')))
  end

  def report_path(scheme = IOS)
    File.join(@root, 'reports', scheme, "#{scheme}.cobertura.xml")
  end

  def test_architecture_is_executed_slice_not_host_or_build_action
    metadata = result('x86_64', 'x86_64')
    metadata['actions']['_values'] << { 'runDestination' => { 'targetArchitecture' => { '_value' => 'arm64' } } }
    assert_equal 'x86_64', MSALCoverage.executed_architecture(metadata)
    assert_equal 'arm64', MSALCoverage.executed_architecture(result('arm64'))
  end

  def test_missing_or_ambiguous_test_architecture_fails
    [result, result(nil), result(''), result('arm64', 'x86_64')].each do |metadata|
      assert_raises(RuntimeError) { MSALCoverage.executed_architecture(metadata) }
    end
  end

  def test_expected_schemes_are_existing_dynamic_frameworks
    assert_equal [IOS, MAC], MSALCoverage::EXPECTED_SCHEMES.values.flatten
    [IOS, MAC].each do |scheme|
      path = File.join(REPO, MSALCoverage::PROJECT, 'xcshareddata/xcschemes', "#{scheme}.xcscheme")
      assert_equal ['MSAL.framework'], MSALCoverage.production_products(path)
    end
  end

  def test_actual_framework_sources_exclude_only_nonowned_compiled_sources
    project = Slather::Project.open(File.join(REPO, MSALCoverage::PROJECT))
    tracked, stderr, status = Open3.capture3('git', 'ls-files', '-z', '--', 'MSAL/src', chdir: REPO)
    assert status.success?, stderr
    [IOS, MAC].each do |scheme|
      target = project.targets.find { |item| item.name == scheme }
      sources = target.source_build_phase.files_references.reject { |file| file.path.end_with?('.docc') }.map do |file|
        file.real_path.relative_path_from(Pathname(REPO)).to_s
      end
      owned = sources.select { |source| source.start_with?('MSAL/src/') }
      refute_empty owned
      assert_empty owned - tracked.split("\0")
      excluded = sources.reject { |source| source.start_with?('MSAL/src/', 'MSAL/IdentityCore/') }
      assert_equal ['MSAL/test/unit/utils/MSALDevicePopManagerUtil.m'], excluded
    end
  end

  def test_export_binds_original_profile_binary_and_executed_architecture
    %w[arm64 x86_64].each do |arch|
      command = ->(*args) { args[1] == 'xcresulttool' ? JSON.generate(result(arch)) : command_result(*args) }
      export(command: command)
      assert_includes @commands, ['xcrun', 'llvm-cov', 'export', '-instr-profile',
                                 File.realpath(@profile), '--arch', arch, File.realpath(@binary)]
      assert_equal arch, @project.arch
      assert_equal 'complete', provenance['status']
      assert_equal 'fixture-revision', provenance['revision']
      assert_equal Digest::SHA256.file(@profile).hexdigest, provenance['profile']['sha256']
      assert_equal Digest::SHA256.file(@binary).hexdigest, provenance['binaries'].first['sha256']
    end
  end

  def test_native_scope_retains_zero_hit_sources_and_excludes_generated_and_unowned
    export
    assert_equal [@owned, @zero], @project.exported_files.map(&:source_file_pathname)
    MSALCoverage.validate_report(report_path)
  end

  def test_symlinked_macos_framework_matches_canonical_native_product
    alias_path = File.join(File.dirname(@binary), 'Versions/A/MSAL')
    FileUtils.mkdir_p(File.dirname(alias_path))
    FileUtils.mv(@binary, alias_path)
    File.symlink('Versions/A/MSAL', @binary)
    export
    assert_equal File.realpath(@binary), provenance['binaries'].first['path']
  end

  def test_missing_or_ambiguous_profile_fails_without_selecting_newest
    File.delete(@profile)
    assert_raises(RuntimeError) { export }
    assert_match 'exactly one profile', provenance['error']
    File.write(@profile, 'profile')
    second = File.join(@derived, 'Build/ProfileData/second/Coverage.profdata')
    FileUtils.mkdir_p(File.dirname(second))
    File.write(second, 'newest profile')
    assert_raises(RuntimeError) { export }
    assert_match 'exactly one profile', provenance['error']
  end

  def test_slather_profile_mismatch_fails
    @project.profile = @binary
    assert_raises(RuntimeError) { export }
    assert_match 'different profile', provenance['error']
  end

  def test_missing_or_duplicate_production_binary_fails
    [[], [@binary, @binary]].each do |binaries|
      @project.binary_file = binaries
      assert_raises(RuntimeError) { export }
      assert_match 'one production binary', provenance['error']
    end
  end

  def test_binary_outside_scheme_local_products_fails
    @project.binary_file = [@profile]
    assert_raises(RuntimeError) { export }
    assert_match 'outside scheme-local products', provenance['error']
  end

  def test_missing_executed_slice_fails
    command = ->(*args) { args[1] == 'lipo' ? 'x86_64' : command_result(*args) }
    assert_raises(RuntimeError) { export(command: command) }
    assert_match 'executed architecture arm64', provenance['error']
  end

  def test_missing_or_ambiguous_native_target_fails
    [[], [{ 'buildProductPath' => @binary }, { 'buildProductPath' => @binary }]].each do |targets|
      command = ->(*args) { args[1] == 'xccov' ? JSON.generate('targets' => targets) : command_result(*args) }
      assert_raises(RuntimeError) { export(command: command) }
      assert_match 'one native production target', provenance['error']
    end
  end

  def test_missing_zero_hit_source_mapping_fails_instead_of_hiding_gap
    @project.coverage_files.delete_at(1)
    assert_raises(RuntimeError) { export }
    assert_match 'Missing native production source mappings', provenance['error']
    refute File.exist?(report_path)
  end

  def test_empty_owned_scope_fails
    command = ->(*args) { args[0] == 'git' && args[1] == 'ls-files' ? '' : command_result(*args) }
    assert_raises(RuntimeError) { export(command: command) }
    assert_match 'No native tracked production sources', provenance['error']
  end

  def test_failed_or_empty_llvm_export_removes_stale_report_but_keeps_other_scheme
    export(MAC)
    original = File.read(report_path(MAC))
    export
    [->(*args) { raise 'llvm-cov failed' if args[1] == 'llvm-cov'; command_result(*args) },
     ->(*args) { args[1] == 'llvm-cov' ? '{"data":[{"files":[]}]}' : command_result(*args) }].each do |command|
      assert_raises(RuntimeError) { export(command: command) }
      refute File.exist?(report_path)
      assert_equal 'failed', provenance['status']
      assert_equal original, File.read(report_path(MAC))
    end
  end

  def write_complete(scheme)
    FileUtils.mkdir_p(File.dirname(report_path(scheme)))
    File.write(report_path(scheme), REPORT)
    directory = File.join(@root, 'diagnostics', scheme)
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, 'provenance.json'), '{"status":"complete"}')
  end

  def test_completeness_accepts_zero_hits_and_requires_every_scheme
    write_complete(IOS)
    MSALCoverage.verify('iosFramework', root: @root)
    assert_raises(RuntimeError) { MSALCoverage.verify('macFramework', root: @root) }
    write_complete(MAC)
    MSALCoverage.verify('macFramework', root: @root)
    MSALCoverage.verify_publication(File.join(@root, 'reports'))
    assert_equal 2, Dir[File.join(@root, 'reports/**/*.xml')].map { |file| File.basename(file) }.uniq.length
  end

  def test_publication_requires_exactly_one_retained_report_per_scheme
    [IOS, MAC].each { |scheme| write_complete(scheme) }
    reports = File.join(@root, 'reports')
    duplicate = File.join(reports, 'duplicate')
    FileUtils.mkdir_p(duplicate)
    File.write(File.join(duplicate, "#{IOS}.cobertura.xml"), REPORT)
    error = assert_raises(RuntimeError) { MSALCoverage.verify_publication(reports) }
    assert_match 'found 2', error.message
    FileUtils.remove_entry(duplicate)
    File.delete(report_path(MAC))
    error = assert_raises(RuntimeError) { MSALCoverage.verify_publication(reports) }
    assert_match MAC, error.message
    assert_match 'found 0', error.message
  end

  def test_empty_malformed_or_incomplete_reports_fail
    ['', '<coverage/>', '<coverage lines-valid="0"/>', '<broken'].each do |report|
      path = File.join(@directory, 'report.xml')
      File.write(path, report)
      assert_raises(StandardError) { MSALCoverage.validate_report(path) }
    end
    write_complete(IOS)
    File.write(File.join(@root, 'diagnostics', IOS, 'provenance.json'), '{"status":"failed"}')
    assert_raises(RuntimeError) { MSALCoverage.verify('iosFramework', root: @root) }
  end

  def publication_fixture
    source = File.join(@directory, 'MSAL/src/owned.m')
    FileUtils.mkdir_p(File.dirname(source))
    File.write(source, 'fixture source')
    [%w[git init -q], %w[git add MSAL/src]].each do |command|
      _, stderr, status = Open3.capture3(*command, chdir: @directory)
      assert status.success?, stderr
    end
    [IOS, MAC].each do |scheme|
      write_complete(scheme)
      xml = REPORT.sub('<packages>', '<sources><source>/producer/checkout</source></sources><packages>')
      File.write(report_path(scheme), xml)
    end
    @prepared = File.join(@root, 'publication')
  end

  def prepare_publication
    MSALCoverage.prepare_publication(File.join(@root, 'reports'), @prepared, checkout: @directory)
  end

  def publication_payload(document)
    REXML::XPath.match(document, '//*').reject { |node| %w[sources source].include?(node.name) }.map do |node|
      [node.name, node.attributes.to_h, node.text.to_s.strip]
    end
  end

  def test_publication_rebases_cross_pool_sources_without_changing_originals_or_counts
    publication_fixture
    originals = [IOS, MAC].to_h { |scheme| [scheme, File.read(report_path(scheme))] }
    prepare_publication
    originals.each do |scheme, original|
      copy = REXML::Document.new(File.read(File.join(@prepared, "#{scheme}.cobertura.xml")))
      assert_equal [@directory], REXML::XPath.match(copy, '/coverage/sources/source').map(&:text)
      assert_equal publication_payload(REXML::Document.new(original)), publication_payload(copy)
      assert_equal original, File.read(report_path(scheme))
      assert_equal '0', REXML::XPath.first(copy, '//line').attributes['hits']
    end
  end

  def test_publication_rejects_traversal_absolute_noncanonical_and_unowned_sources
    publication_fixture
    ['/producer/checkout/MSAL/src/owned.m', 'MSAL/src/../src/owned.m', 'MSAL/src/./owned.m',
     'MSAL/src//owned.m', 'MSAL\\src\\owned.m', 'MSAL/src/untracked.m',
     'MSAL/test/test.m', 'MSAL/IdentityCore/source.m'].each do |path|
      File.write(report_path(IOS), REPORT.sub('MSAL/src/owned.m', path))
      error = assert_raises(RuntimeError) { prepare_publication }
      assert_match 'Unowned or noncanonical', error.message
      refute File.exist?(File.join(@prepared, "#{IOS}.cobertura.xml"))
      assert File.file?(File.join(@prepared, "#{MAC}.cobertura.xml"))
    end
  end

  def test_publication_rejects_symlink_escape_and_missing_source
    publication_fixture
    source = File.join(@directory, 'MSAL/src/owned.m')
    File.delete(source)
    error = assert_raises(RuntimeError) { prepare_publication }
    assert_match 'Missing publication source', error.message
    [@owned.to_s, File.expand_path(__FILE__)].each do |destination|
      File.symlink(destination, source)
      error = assert_raises(RuntimeError) { prepare_publication }
      assert_match 'escapes tracked production', error.message
      assert_empty Dir[File.join(@prepared, '*.cobertura.xml')]
      File.delete(source)
    end
  end

  def test_publication_failure_clears_stale_copies_and_preserves_valid_peer
    publication_fixture
    prepare_publication
    original = File.read(report_path(MAC))
    File.delete(report_path(IOS))
    assert_raises(RuntimeError) { prepare_publication }
    refute File.exist?(File.join(@prepared, "#{IOS}.cobertura.xml"))
    assert File.file?(File.join(@prepared, "#{MAC}.cobertura.xml"))
    assert_equal original, File.read(report_path(MAC))
    File.write(report_path(IOS), '<broken')
    assert_raises(RuntimeError) { prepare_publication }
    assert File.file?(File.join(@prepared, "#{MAC}.cobertura.xml"))
  end

  def test_publication_rejects_overlapping_output_and_duplicate_inputs
    publication_fixture
    reports = File.join(@root, 'reports')
    [reports, File.join(reports, 'copies'), @root].each do |output|
      assert_raises(RuntimeError) { MSALCoverage.prepare_publication(reports, output, checkout: @directory) }
      assert File.file?(report_path(IOS))
    end
    duplicate = File.join(reports, 'duplicate')
    FileUtils.mkdir_p(duplicate)
    FileUtils.cp(report_path(IOS), File.join(duplicate, "#{IOS}.cobertura.xml"))
    error = assert_raises(RuntimeError) { prepare_publication }
    assert_match 'found 2', error.message
    refute File.exist?(File.join(@prepared, "#{IOS}.cobertura.xml"))
    assert File.file?(File.join(@prepared, "#{MAC}.cobertura.xml"))
  end

  def test_command_failures_and_stale_profile_warnings_surface
    assert_raises(RuntimeError) { MSALCoverage.run(RbConfig.ruby, '-e', 'exit 9') }
    ['profile data may be out of date', 'mismatched profile'].each do |warning|
      assert_raises(RuntimeError) { MSALCoverage.run(RbConfig.ruby, '-e', "warn #{warning.inspect}") }
    end
  end

  def pipeline
    YAML.load_file(File.join(REPO, 'azure_pipelines/pr-validation.yml'))
  end

  def publication
    pipeline.fetch('jobs').map { |job| job.fetch('parameters') }.find { |job| job['jobName'] == 'Publish_coverage' }
  end

  def handoff
    YAML.load_file(File.join(REPO, 'azure_pipelines/templates/coverage-handoff.yml')).fetch('steps')
  end

  def test_pipeline_keeps_existing_test_targets_and_publishes_once
    jobs = pipeline.fetch('jobs').map { |job| job.fetch('parameters') }
    %w[iOS macOS].each do |platform|
      job = jobs.find { |item| item['jobName'] == "Validate_Pull_Request_#{platform}" }
      build = job.fetch('steps').find { |step| step['displayName'] == 'Run Build script & check for Errors' }
      expected = platform == 'iOS' ? 'iosFramework iosTestApp sampleIosApp sampleIosAppSwift' : 'macFramework'
      assert_includes build.fetch('inputs')['script'], "./build.py --coverage --targets #{expected}"
      assert_equal 1, build.fetch('inputs')['script'].scan('./build.py').length
      assert job.fetch('steps').any? { |step| step['template'] == 'templates/coverage-handoff.yml' }
      refute job.fetch('steps').any? { |step| step['task'] == 'PublishCodeCoverageResults@2' }
    end
    assert_equal %w[Validate_Pull_Request_iOS Validate_Pull_Request_macOS], publication['dependsOn']
    assert_equal 'succeededOrFailed()', publication['condition']
    publishers = jobs.flat_map { |job| job.fetch('steps') }.select { |step| step['task'] == 'PublishCodeCoverageResults@2' }
    assert_equal 1, publishers.length
    assert_equal 'succeededOrFailed()', publishers.first['condition']
    assert publishers.first.fetch('inputs')['failIfCoverageEmpty']
    assert_includes publishers.first.fetch('inputs')['summaryFileLocation'], '/publication/*.cobertura.xml'
    download = publication.fetch('steps').find { |step| step['task'] == 'DownloadPipelineArtifact@2' }
    assert_equal 'current', download.fetch('inputs')['buildType']
    assert_equal '**/*.cobertura.xml', download.fetch('inputs')['itemPattern']
  end

  def test_xml_handoff_survives_failure_and_only_collection_gaps_upload_diagnostics
    retained = handoff.find { |step| step['displayName'] == 'Retain scheme coverage reports' }
    assert_equal 'succeededOrFailed()', retained['condition']
    diagnostic = handoff.find { |step| step['displayName'] == 'Publish coverage collection diagnostics' }
    assert_equal "and(succeededOrFailed(), eq(variables['coverageCollectionFailed'], 'true'))", diagnostic['condition']
    verifier = handoff.find { |step| step['displayName'] == 'Verify all expected coverage reports' }
    assert_equal 'succeededOrFailed()', verifier['condition']
    refute verifier['continueOnError']
    script = verifier.fetch('inputs')['script'].sub('${{ parameters.target }}', 'iosFramework')
    [0, 7].each do |code|
      stdout, stderr, status = Open3.capture3('bash', '-c', "ruby() { return #{code}; }\n#{script}", chdir: @directory)
      assert_equal code.zero?, status.success?, stderr
      assert_includes stdout, "##vso[task.setvariable variable=coverageCollectionFailed]#{code.zero? ? 'false' : 'true'}"
    end
  end

  def test_platform_html_uses_same_unique_xmls_after_native_publication
    steps = publication.fetch('steps')
    native_index = steps.index { |step| step['task'] == 'PublishCodeCoverageResults@2' }
    verifier = steps.find { |step| step['displayName'] == 'Prepare validated publication copies' }
    assert_equal 'succeededOrFailed()', verifier['condition']
    assert_includes verifier.fetch('inputs')['script'], 'prepare-publication build/coverage/reports build/coverage/publication'
    assert_operator steps.index(verifier), :<, native_index
    restore = steps.find { |step| step['displayName'] == 'Restore pinned HTML report generator' }
    assert_operator native_index, :<, steps.index(restore)
    assert_includes restore.fetch('inputs')['script'], '--tool-manifest .config/dotnet-tools.json'
    runtime = steps.find { |step| step['task'] == 'UseDotNet@2' }
    assert_equal '8.x', runtime.fetch('inputs')['version']
    assert_operator steps.index(runtime), :<, native_index
    assert_equal '5.4.18', JSON.parse(File.read(File.join(REPO, '.config/dotnet-tools.json')))
                             .fetch('tools').fetch('dotnet-reportgenerator-globaltool').fetch('version')
    { 'iOS' => IOS, 'macOS' => MAC }.each do |platform, scheme|
      generator = steps.find { |step| step['displayName'] == "Generate #{platform} coverage HTML" }
      assert_equal 'succeededOrFailed()', generator['condition']
      script = generator.fetch('inputs')['script']
      assert_includes script, "-reports:build/coverage/publication/#{scheme}.cobertura.xml"
      assert_includes script, "-targetdir:build/coverage/html/#{platform}"
      assert_includes script, '-sourcedirs:$PWD'
      assert_includes script, '-reporttypes:Html'
      artifact = steps.find { |step| step['displayName'] == "Publish #{platform} coverage HTML" }
      assert_equal 'succeededOrFailed()', artifact['condition']
      assert_equal "MSAL #{platform} coverage HTML - $(System.JobAttempt)", artifact.fetch('inputs')['artifact']
    end
  end

  def test_real_reportgenerator_keeps_platform_html_independent
    skip 'Set MSAL_COVERAGE_HTML_FIXTURE=1 after restoring the pinned tool' unless ENV['MSAL_COVERAGE_HTML_FIXTURE'] == '1'
    publication_fixture
    FileUtils.mkdir_p(File.join(@directory, '.config'))
    FileUtils.cp(File.join(REPO, '.config/dotnet-tools.json'), File.join(@directory, '.config/dotnet-tools.json'))
    { 'iOS' => [IOS, 0], 'macOS' => [MAC, 1] }.each do |platform, (scheme, hits)|
      xml = REPORT.sub('<packages>', '<sources><source>/old/agent/checkout</source></sources><packages>')
                  .sub('lines-covered="0"', "lines-covered=\"#{hits}\"").sub('hits="0"', "hits=\"#{hits}\"")
      File.write(report_path(scheme), xml)
    end
    MSALCoverage.prepare_publication(File.join(@root, 'reports'), File.join(@directory, 'build/coverage/publication'),
                                     checkout: @directory)
    { 'iOS' => [IOS, 0], 'macOS' => [MAC, 1] }.each do |platform, (scheme, hits)|
      original = File.read(report_path(scheme))
      generator = publication.fetch('steps').find { |step| step['displayName'] == "Generate #{platform} coverage HTML" }
      stdout, stderr, status = Open3.capture3('bash', '-c', generator.fetch('inputs')['script'], chdir: @directory)
      assert status.success?, "#{stdout}\n#{stderr}"
      index = File.join(@directory, "build/coverage/html/#{platform}/index.html")
      assert File.file?(index)
      html = File.read(index)
      assert_includes html, "MSAL #{platform} coverage"
      assert_includes html, hits.zero? ? '0%' : '100%'
      pages = Dir[File.join(File.dirname(index), '*.html')].reject { |path| path == index }
      assert pages.any? { |path| File.read(path).match?(/fixture.*source/m) },
             "Source not resolved in #{pages.inspect}: #{stdout}\n#{stderr}"
      assert_equal original, File.read(report_path(scheme))
    end
    assert File.file?(File.join(@directory, 'build/coverage/html/iOS/index.html'))
    assert File.file?(File.join(@directory, 'build/coverage/html/macOS/index.html'))
  end

  def test_pipeline_build_failure_and_missing_status_cannot_report_success
    task = pipeline.fetch('jobs').first.fetch('parameters').fetch('steps')
                   .find { |step| step['displayName'] == 'Run Build script & check for Errors' }
    script = task.fetch('inputs')['script']
    FileUtils.mkdir_p(File.join(@directory, 'build'))
    { ['0', 0] => true, ['1', 0] => false, ['0', 65] => false, [nil, 9] => false }.each do |(value, exit_code), success|
      runner = File.join(@directory, 'build.py')
      File.write(runner, "#!/bin/bash\n#{value ? "echo #{value} > build/status.txt" : ''}\nexit #{exit_code}\n")
      File.chmod(0o755, runner)
      _, stderr, status = Open3.capture3('bash', '-c', script, chdir: @directory)
      assert_equal success, status.success?, stderr
    end
  end

  def test_real_llvm_and_slather_preserve_counts_and_scope
    skip 'Set MSAL_COVERAGE_LLVM_FIXTURE=1 for standalone LLVM fixture export' unless ENV['MSAL_COVERAGE_LLVM_FIXTURE'] == '1'
    checkout = File.join(@directory, 'fixture checkout')
    owned = File.join(checkout, 'MSAL/src/owned.c')
    unowned = File.join(checkout, 'MSAL/test/test.c')
    [owned, unowned].each { |file| FileUtils.mkdir_p(File.dirname(file)) }
    File.write(owned, "int zero(void) {\n  return 42;\n}\nint tested(void) {\n  return 0;\n}\n")
    File.write(unowned, "int tested(void);\nint main(void) { return tested(); }\n")
    MSALCoverage.run('xcrun', 'clang', '-fprofile-instr-generate', '-fcoverage-mapping', owned, unowned, '-o', @binary)
    raw = File.join(@directory, 'fixture.profraw')
    _, stderr, status = Open3.capture3({ 'LLVM_PROFILE_FILE' => raw }, [@binary, @binary])
    assert status.success?, stderr
    MSALCoverage.run('xcrun', 'llvm-profdata', 'merge', '-sparse', raw, '-o', @profile)
    arch = MSALCoverage.run('xcrun', 'lipo', '-archs', @binary).strip
    original_run = MSALCoverage.method(:run)
    command = lambda do |*args|
      if args[1] == 'xcresulttool'
        JSON.generate(result(arch))
      elsif args[1] == 'xccov'
        JSON.generate('targets' => [{ 'buildProductPath' => @binary,
                                     'files' => [owned, unowned].map { |file| { 'path' => file, 'executableLines' => 6 } } }])
      elsif args == ['git', 'ls-files', '-z', '--', 'MSAL/src']
        "MSAL/src/owned.c\0"
      elsif args == ['git', 'rev-parse', 'HEAD']
        'standalone-llvm-fixture'
      else
        original_run.call(*args)
      end
    end
    Dir.chdir(checkout) do
      MSALCoverage.stub(:run, command) do
        MSALCoverage.export(IOS, @derived, 'fixture.xcresult', root: @root,
                            project_path: File.join(REPO, MSALCoverage::PROJECT))
      end
    end
    document = REXML::Document.new(File.read(report_path))
    assert_equal ['MSAL/src/owned.c'], REXML::XPath.match(document, '//class').map { |node| node.attributes['filename'] }
    lines = REXML::XPath.match(document, '//line').to_h { |node| [node.attributes['number'], node.attributes['hits'].to_i] }
    assert_equal 0, lines.fetch('2')
    assert_equal 1, lines.fetch('5')
    assert_equal 'complete', provenance['status']
  end
end
