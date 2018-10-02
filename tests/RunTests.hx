package;

import tink.unit.*;
import tink.testrunner.*;

class RunTests {
	static function main() {
		Runner.run(TestBatch.make([
			new InstallHaxeTest(),
			new InstallTest(),
		])).handle(Runner.exit);
	}
}