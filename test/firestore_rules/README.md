# Local leaderboard security checks

These tests exercise real Firestore rules with the standalone emulator. They use
synthetic authentication tokens and the fixed `demo-chiroless` project on
`127.0.0.1:8185`. They do not contact the production project or read Firebase CLI
credentials. Node 18+ and Java 21+ are required; no npm dependencies are needed.

Download the official emulator JAR into a temporary directory. The URL below is
the Firestore version listed by the installed Firebase Tools 15.32.1 metadata.

```sh
curl -fL https://storage.googleapis.com/firebase-preview-drop/emulator/cloud-firestore-emulator-v1.22.0.jar -o /tmp/chiroless-firestore-emulator.jar
```

From the repository root, start the emulator in one terminal:

```sh
java -jar /tmp/chiroless-firestore-emulator.jar --host=127.0.0.1 --port=8185 --project_id=demo-chiroless --rules=firestore.rules
```

Wait for `Dev App Server is now running`, then run the checks in a second terminal:

```sh
node --test --test-isolation=none test/firestore_rules/leaderboard_rules.test.mjs
```

The runner loads `firestore.rules`, checks compilation, and clears the local demo
database before each test. Stop the emulator with Ctrl+C afterward. A restricted
runtime may require approval for local sockets or for Node's test subprocess.

On 2026-10-08, all 12 tests passed against emulator 1.22.0 with this command.
The preceding run of the incompatible `math.isInfinite` guard failed five
publication tests with `Function not found: math.isInfinite`. The current
subtraction guard accepts finite percentages and rejects NaN and both infinities.

The checks cover opt-in and withdrawal, atomic batch state, signed-in ranking
reads, private financial data, owner-only publication, server timestamps, valid
months, schema restrictions, and finite percentages. They do not prove that a
client-supplied percentage matches private transaction totals; that calculation
is tested separately in the Flutter service tests.

For a comparison against older rules, export a known commit to a temporary file
and select it with `LOCAL_FIRESTORE_RULES`. This changes only the local emulator:

```sh
git show fc9b58e:firestore.rules > /tmp/chiroless-baseline-firestore.rules
LOCAL_FIRESTORE_RULES=/tmp/chiroless-baseline-firestore.rules node --test --test-isolation=none --test-name-pattern='owner publishes finite' test/firestore_rules/leaderboard_rules.test.mjs
```

The baseline should deny the new ranking publication test. Run the complete
suite afterward to restore and verify the current rules.
