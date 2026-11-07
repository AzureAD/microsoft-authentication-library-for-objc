# MSAL XCUITest code-coverage pilot

`automation.yml` enables `ui_code_coverage` only for the existing **MSAL Test
Automation (iOS)** simulator job. The shared template defaults it off. Native
Auth E2E, unit tests, installed older MSAL/ADAL apps, brokers, and IdentityCore
are not coverage scopes. No feature or scenario coverage is inferred.

The existing `build-for-testing` and `test-without-building` executions enable
Xcode coverage. There is no extra automation execution, scheme change, shipping
build setting, or threshold. Test selection, destination, parallelism, three
retry iterations, and result-bundle location remain unchanged.

## Collection and retained evidence

The preparation helper validates the generated xctestrun has exactly the two
expected UI targets, `InteractiveiOSTests` and `MultiAppiOSTests`. It changes only
their **target app** profiling environment, not the runner environment or test
selection. It retains each app's embedded MSAL binary and app executable, never
the app/test bundles or xctestrun, which can contain configuration credentials.
The pilot rejects ambiguous xctestruns and multi-architecture products instead
of guessing which binary ran.

Each target gets a separate profile directory. LLVM `%m-%p%c` filenames separate
images and app processes; Darwin continuous profiling maps counters to disk so
forced app termination does not rely on `applicationWillTerminate` or `atexit`.
The helper tests compile a tiny dynamic-library fixture with the selected LLVM
toolchain, kill and relaunch it, then verify both executed branches survive in
the reports. They do not start Xcode, a simulator, or an authentication test.

Coverage is **the union of all iterations, including failed attempts and test
retries**, not first-pass coverage and not per-test coverage. Stage/job attempts
have distinct artifact names and provenance; their profiles are never merged.
Per-process filenames are retained, but do not identify which individual test
iteration produced each process.

LLVM exports only the exercised app's embedded MSAL framework. Report
denominators include mapped production files under `MSAL/src`, including mapped
uncovered lines; they do not represent every source file in the repository or
code executed in external installed applications. LLVM's native LCOV line
records are cross-checked against its JSON totals. Missing profiles, unexecuted
MSAL initialization, source-root mismatches, changed source/binary hashes, and
LLVM warnings fail collection rather than producing a zero-coverage success.
Still-running app processes and profiles that change during export also fail
collection instead of silently publishing a non-final snapshot.
No native XML is made publishable until both target scopes pass collection.

The `MSAL-XCUITest-Coverage-<build>-stage<attempt>-job<attempt>` artifact retains:

- Matched binaries, raw profiles, merged profiles, LLVM JSON and LCOV exports.
- Provenance: commit, destination, architecture, retry policy, build/attempt IDs,
  source/binary/profile hashes, selected/skipped identifiers, and per-target totals.
- Unique `reports/msal-xcuitest-<target>.cobertura.xml` files with repository-relative
  filenames and the build source root, plus self-contained HTML source-detail pages.
- An explicit `collection-error.json` when collection is incomplete.

A single `PublishCodeCoverageResults@2` invocation publishes both scope XMLs
with `pathToSources` set to the original source checkout. Unit-test reporting
is separate. Do not introduce another native publisher in this pipeline without
centralizing its inputs; multiple publishers can overwrite the build coverage UI.

## Acceptance and limitations

Run helper checks without Xcode builds:

```sh
python3 -m unittest discover -s azure_pipelines/scripts -p 'test_automation_coverage.py' -v
```

A hosted run of the changed head is still required to accept this pilot. In that
existing automation execution, verify the generated xctestrun app environment
survives Xcode's launch/relaunch handling; both targets produce current MSAL
profiles after forced termination; and the artifact XML/HTML totals agree with
the retained LLVM exports. Check the Azure DevOps native coverage UI includes
both scopes, resolves production-source detail links, and handles their shared
source filenames correctly. A green test run alone is not coverage acceptance.

The reports measure lines only, not LLVM branch or feature/scenario coverage.
The local dynamic-library probe is **not** evidence that the real iOS automation
app collected profiles or that native Azure DevOps links resolve. This pilot
deliberately fails unsupported runtime/mapping conditions; it does not add
callbacks or change UI-test lifecycle to manufacture coverage.

Historical TestOutputs result bundles do not establish reconstructable coverage.
Do not reconstruct a historical report unless matching instrumented products
and profiles are available. Never inspect or publish Key Vault configuration,
LabAuth, or authentication logs as part of coverage diagnostics.
